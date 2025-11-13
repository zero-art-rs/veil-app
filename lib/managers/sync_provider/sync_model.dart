import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:queue/queue.dart';
import 'package:veil/api/centrifugo.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/managers/chat/chat_manager.dart';
import 'package:veil/managers/contacts_manager.dart';
import 'package:veil/managers/sharing/deeplink_manager.dart';
import 'package:veil/managers/sync_provider/buffer.dart';
import 'package:veil/managers/sync_provider/queue_process_listener.dart';
import 'package:veil/managers/sync_provider/sync_model_errors.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/consts.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/editor_automerge.dart';
import 'package:veil/utils/group_context_factory.dart';
import 'package:veil/utils/local_state.dart';
import 'package:veil/utils/payload.dart';
import 'package:veil/utils/secret_factory.dart';

import '../../main.dart';

class SyncModel {
  final DocumentState documentState;
  final BGroupContext groupContext;
  final ChatManager chatManager;
  CentrifugoListener? listener;
  final _db = DB.instance;

  final _crdtBuffer = LockedBuffer<ExposedCRDTPayload>();
  final _processQueue = Queue();
  final _sendQueue = Queue();
  late final _queueProcessListener = StreamProcessListener(
    streams: [_sendQueue.remainingItems, _processQueue.remainingItems],
  );

  bool bufferFrames = true;
  bool corrupted = false;
  get isLocal => documentState.isLocal;

  final _corrupedEvent = StreamController<bool>.broadcast();
  final _groupInfoUpdatesEvent = StreamController<bool>.broadcast();
  final _crdtUpdatesEvent = StreamController<BAutoCommit>.broadcast();
  final _removedFromGroupEvent = StreamController<bool>.broadcast();

  Stream<bool> get corruptedEvent => _corrupedEvent.stream;
  Stream<bool> get groupInfoUpdateEvent => _groupInfoUpdatesEvent.stream;
  Stream<BAutoCommit> get crdtUpdatesEvent => _crdtUpdatesEvent.stream;
  Stream<bool> get removedFromGroupEvent => _removedFromGroupEvent.stream;
  Stream<bool> get isProcessing => _queueProcessListener.isProcessing;

  String _previousGroupInfoHash = '';

  SyncModel({
    required this.documentState,
    required this.groupContext,
    required this.listener,
    required this.chatManager,
    this.corrupted = false,
  });

  bool isUserInGroup() {
    return groupContext.retrieveGroupInfo().members.any(
      (e) => e.id == AccountSecureStorage.instance.account.actorId,
    );
  }

  bool isChangingGroupMetaAllowed() {
    return groupContext
            .retrieveGroupInfo()
            .members
            .firstWhereOrNull(
              (e) => e.id == AccountSecureStorage.instance.account.actorId,
            )
            ?.role
            .value ==
        ownerRole;
  }
}

extension SyncModelInit on SyncModel {
  void _handleCrdt(ExposedCRDTPayload crdt, bool allowFullDocument) {
    switch (crdt.kind) {
      case ExposedCRDTPayloadKind.incrementalChange:
        documentState.crdt.loadIncremental(bytes: crdt.crdt.incrementalChange);
      case ExposedCRDTPayloadKind.fullDocument:
        if (!allowFullDocument) return;
        logger.debug('Received crdt full document');
        documentState.crdt = BAutoCommit.load(data: crdt.crdt.fullDocument);
    }
  }

  void listenCentrifugo() {
    _queueProcessListener.listen();
  }

  Future<void> synchronizeInitially({bool allowFullDocument = false}) async {
    logger.debug(
      'Document epoch before polling: ${(await groupContext.epoch()).toInt()}',
    );
    logger.debug(
      'Document sequence number before polling: ${documentState.sequenceNumber}',
    );

    while (true) {
      final signature = await groupContext.signWithTk(
        groupId: documentState.id,
        nonce: [0],
      );

      final result = await GroupApiClient.instance.getFrames(
        epoch: (await groupContext.epoch()).toInt(),
        groupId: documentState.id,
        signature: base64UrlEncode(signature),
        nonce: base64UrlEncode([0]),
        messageSequenceNumber: documentState.sequenceNumber,
      );

      if (result.spFrames.first.seqNum.toInt() ==
          documentState.sequenceNumber) {
        break;
      }

      for (final spFrame in result.spFrames.reversed) {
        logger.debug(
          'Current processing frame epoch: ${(await groupContext.epoch()).toInt()}',
        );
        logger.debug(
          'Current processing frame seqNum: ${spFrame.seqNum.toInt()}',
        );

        final crdtList = await _processFrame(spFrame);

        for (final crdt in crdtList) {
          _handleCrdt(crdt, allowFullDocument);
        }
      }
    }

    logger.info('Updating document state..');
    await _db.updateDocumentState(
      documentState: documentState,
      groupContextParts: await groupContext.asParts(),
    );

    logger.debug(
      'Document sequence number after polling: ${documentState.sequenceNumber}',
    );
    logger.debug(
      'Document epoch after polling: ${(await groupContext.epoch()).toInt()}',
    );
  }

  Future<void> dispose() async {
    _processQueue.cancel();
    _sendQueue.cancel();

    await listener?.disconnect();
    await _removedFromGroupEvent.close();
    await _groupInfoUpdatesEvent.close();
    await _crdtUpdatesEvent.close();
    logger.info('Sync provider disposed');
  }
}

extension SyncModelHandle on SyncModel {
  Future<void> bufferizeFrames() async {
    try {
      await _processQueue.add(() async {
        logger.info('Change process frames to buffer mode');
        bufferFrames = true;
      });
    } on QueueCancelledException {
      logger.debug('Process queue cancelled');
    }
  }

  Future<void> applyBufferedFrames() async {
    try {
      await _processQueue.add(() async {
        final snapshot = await _crdtBuffer.snapshot();
        await applyCrdtListOperation(snapshot);
        await _crdtBuffer.removeWhere((e) => snapshot.contains(e));
        _emitCrdtUpdatesEvent();
        bufferFrames = false;
        logger.info('Change process frames to process mode');
      });
    } on QueueCancelledException {
      logger.debug('Process queue cancelled');
    }
  }
}

extension SyncModelProcessOperations on SyncModel {
  Future<void> processFrame(SPFrame spframe) async {
    try {
      await _processQueue.add(() async {
        logger.info('Received frame, processing..');
        logger.debug(
          'Received frame, frame epoch: ${spframe.frame.frame.epoch}..',
        );
        logger.debug('Received frame, frame seqNum: ${spframe.seqNum}..');

        _previousGroupInfoHash = sha256
            .convert(groupContext.groupInfo())
            .toString();

        final crdtList = await _processFrame(spframe);

        final currentGroupInfoHash = sha256
            .convert(groupContext.groupInfo())
            .toString();

        if (currentGroupInfoHash != _previousGroupInfoHash &&
            !_groupInfoUpdatesEvent.isClosed) {
          logger.info('Group info changed, sending update..');
          _emitGroupInfoUpdatesEvent();
        }

        if (bufferFrames) {
          logger.debug('Buffering crdt frames...');
          for (final payload in crdtList) {
            await _crdtBuffer.push(payload);
          }
        } else {
          logger.debug('Applying crdt frames...');
          final snapshot = await _crdtBuffer.snapshot();
          snapshot.addAll(crdtList);
          await applyCrdtListOperation(snapshot);
          await _crdtBuffer.removeWhere((e) => snapshot.contains(e));
          _emitCrdtUpdatesEvent();
        }
      });
    } on QueueCancelledException {
      logger.debug('Process queue cancelled');
    } catch (e) {
      if (isUserRemovedError(e)) {
        logger.info('User removed from group, making local only');
        _emitRemovedFromGroupEvent();
        await disableNetworkSyncOperation();
      } else {
        rethrow;
      }
    }
  }
}

extension SyncModelSendOperations on SyncModel {
  Future<void> leaveGroup() async {
    const maxAttempts = 3;

    try {
      await _sendQueue.add(() async {
        for (var attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            logger.info('Sending leave group frame..');
            final frame = await groupContext.leaveGroup();

            await _db.updateGroupContextDocumentState(
              id: documentState.id,
              parts: await groupContext.asParts(),
            );

            await GroupApiClient.instance.sendFrame(
              groupId: documentState.id,
              frame: frame,
            );

            logger.info('Sent leave group frame');
            await _db.updateDocumentState(
              documentState: documentState,
              groupContextParts: await groupContext.asParts(),
            );

            break;
          } catch (e) {
            if (attempt == 3) {
              logger.warning('Failed to send leave group frame: $e');
              rethrow;
            } else {
              logger.warning(
                'Failed to invite member, attempt: $attempt, max attempts: $maxAttempts, retrying..: $e',
              );
            }
          }
        }
      });
    } on QueueCancelledException {
      logger.debug('Send queue cancelled');
    }
  }

  Future<void> sendCrdtFrame(String md) async {
    const maxAttempts = 3;

    try {
      await _sendQueue.add(() async {
        for (var attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            logger.info('Sending crdt frame..');
            final snapshot = await _crdtBuffer.snapshot();
            await _sendCrdtFrame(md, snapshot);
            await _crdtBuffer.removeWhere((e) => snapshot.contains(e));
            _emitCrdtUpdatesEvent();
            logger.info('Sent crdt frame');
            break;
          } catch (e) {
            if (attempt == maxAttempts) {
              logger.error('Failed to send crdt frame: $e');
              rethrow;
            } else {
              logger.warning(
                'Failed to invite member, attempt: $attempt, max attempts: $maxAttempts, retrying..: $e',
              );
            }
          }
        }
      });
    } on QueueCancelledException {
      logger.debug('Send queue cancelled');
    }
  }

  Future<void> sendChatFrame(List<int> messageBytes) async {
    const maxAttempts = 3;

    try {
      await _sendQueue.add(() async {
        for (var attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            await _sendChatFrame(messageBytes);
            break;
          } catch (e) {
            if (attempt == maxAttempts) {
              logger.error('Failed to send chat frame: $e');
              rethrow;
            } else {
              logger.warning(
                'Failed to invite member, attempt: $attempt, max attempts: $maxAttempts, retrying..: $e',
              );
            }
          }
        }
      });
    } on QueueCancelledException {
      logger.debug('Send queue cancelled');
    }
  }

  Future<void> updateGroupName({required String name}) async {
    try {
      await _sendQueue.add(() async {
        logger.info('Creating change group frame...');
        final frame = await groupContext.changeGroup(name: name);

        await _db.updateGroupContextDocumentState(
          id: documentState.id,
          parts: await groupContext.asParts(),
        );

        logger.info('Sending change group frame...');
        await GroupApiClient.instance.sendFrame(
          groupId: documentState.id,
          frame: frame,
        );
        logger.info('Change group frame was sent');
      });
    } on QueueCancelledException {
      logger.debug('Send queue cancelled');
    }
  }

  Future<void> updateUserName({required String name}) async {
    try {
      await _sendQueue.add(() async {
        logger.info('Creating change user frame...');
        final frame = await groupContext.changeUser(name: name);

        await _db.updateGroupContextDocumentState(
          id: documentState.id,
          parts: await groupContext.asParts(),
        );

        logger.info('Sending change user frame...');
        await GroupApiClient.instance.sendFrame(
          groupId: documentState.id,
          frame: frame,
        );
        logger.info('Change user frame was sent');
      });
    } on QueueCancelledException {
      logger.debug('Send queue cancelled');
    }
  }

  Future<String> createIdentifiedMemberLink({required Contact contact}) async {
    const maxAttempts = 3;

    try {
      return await _sendQueue.add(() async {
        for (var attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            logger.info('Creating identified member invite..');
            final firstSpk = contact.spks.firstOrNull;
            final spkPublicKey = firstSpk != null
                ? Uint8List.fromList(firstSpk)
                : null;

            logger.info('Spk to use apply: $spkPublicKey');

            final payload = Payload(
              crdt: CRDTPayload(fullDocument: documentState.crdt.save()),
            );

            logger.info('Creating identified invite frame');
            final (frame, invite) = await groupContext.addIdentifiedMember(
              identityPublicKey: contact.account.rawPublicKey,
              spkPublicKey: spkPublicKey,
              content: Payloads(payloads: [payload]).writeToBuffer(),
            );

            await _db.updateGroupContextDocumentState(
              id: documentState.id,
              parts: await groupContext.asParts(),
            );

            logger.info('Sending identified invite frame');
            await GroupApiClient.instance.sendFrame(
              groupId: documentState.id,
              frame: frame,
            );
            logger.info('Identified invite frame sent');

            final inviteLink = DeeplinkManager.instance.buildInvite(invite);

            if (spkPublicKey != null) {
              logger.info('Removing spk contact spk..');
              await ContactsManager.instance.removeSpk(
                contact.account.actorId,
                spkPublicKey.toList(),
              );
            }

            return inviteLink;
          } catch (e) {
            if (attempt == maxAttempts) {
              logger.error('Failed to create identified member link: $e');
              rethrow;
            } else {
              logger.warning(
                'Failed to create identified member link, attempt: $attempt, max attempts: $maxAttempts, retrying..: $e',
              );
            }
          }
        }

        throw StateError(
          'Unreachable: indentified invite retry loop exited unexpectedly',
        );
      });
    } on QueueCancelledException {
      logger.debug('Send queue cancelled');
      return "";
    }
  }

  Future<String> createUnidentifiedMemberInviteLink() async {
    const maxAttempts = 3;

    try {
      return await _sendQueue.add(() async {
        for (var attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            logger.info('Creating unidentified member invite..');
            final secretKey = SecretManager.intance.generateSecretKey();

            final payloads = Payloads(
              payloads: [
                Payload(
                  crdt: CRDTPayload(fullDocument: documentState.crdt.save()),
                ),
              ],
            ).writeToBuffer();

            logger.info('Creating unidentified invite frame..');
            final (frame, invite) = await groupContext.addUnidentifiedMember(
              secretKey: secretKey,
              content: payloads,
            );

            await _db.updateGroupContextDocumentState(
              id: documentState.id,
              parts: await groupContext.asParts(),
            );

            logger.info('Sending unidentified invite frame...');
            await GroupApiClient.instance.sendFrame(
              groupId: documentState.id,
              frame: frame,
            );
            logger.info('Unidentified invite frame sent');

            return DeeplinkManager.instance.buildInvite(invite);
          } catch (e) {
            if (attempt == maxAttempts) {
              logger.error(
                'Failed to create unidentified invite member link: $e',
              );
              rethrow;
            } else {
              logger.warning(
                'Failed to create unidentified invite member link, attempt: $attempt, max attempts: $maxAttempts, retrying..: $e',
              );
            }
          }
        }

        throw StateError('Unreachable: invite retry loop exited unexpectedly');
      });
    } on QueueCancelledException {
      logger.debug('Send queue cancelled');
      return "";
    }
  }

  Future<void> removeMember({required String actorId}) async {
    try {
      await _sendQueue.add(() async {
        logger.info('Removing member in group context..');
        final frame = await groupContext.removeMember(
          userId: actorId,
          content: [],
        );

        await _db.updateGroupContextDocumentState(
          id: documentState.id,
          parts: await groupContext.asParts(),
        );

        logger.info('Sending remove member frame...');
        await GroupApiClient.instance.sendFrame(
          groupId: documentState.id,
          frame: frame,
        );

        logger.info('Remove member frame sent');
      });
    } on QueueCancelledException {
      logger.debug('Send queue cancelled');
    }
  }

  Future<void> sendJoinGroupFrame(Account user) async {
    const maxAttempts = 3;

    try {
      await _sendQueue.add(() async {
        for (var attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            await _sendJoinGroupFrame(user);
            break;
          } catch (e) {
            if (attempt == maxAttempts) {
              logger.error('Failed to send join group frame: $e');
              rethrow;
            } else {
              logger.warning(
                'Failed to send join group frame, attempt: $attempt, max attempts: $maxAttempts, retrying..: $e',
              );
            }
          }
        }
      });
    } on QueueCancelledException {
      logger.debug('Send queue cancelled');
    }
  }
}

extension SyncModelOperations on SyncModel {
  Future<void> markAsCorrupted() async {
    logger.info('Highlighting corrupted document..');

    corrupted = true;
    _emitCorruptedEvent();
    await dispose();
    logger.info('Corrupted document highlighted');
  }

  Future<void> applyCrdtListOperation(List<ExposedCRDTPayload> payloads) async {
    logger.info('Applying crdt list..');

    _syncDocumentWithCrdt(documentState, payloads);

    logger.info('Updating document state..');
    await _db.updateDocumentState(
      documentState: documentState,
      groupContextParts: await groupContext.asParts(),
    );

    logger.info('Applied crdt list');
  }

  Future<void> disableNetworkSyncOperation() async {
    await listener?.disconnect();
    await dispose();
    documentState.isLocal = true;

    LocalStateUtils.instance.makeDocumentLocal(documentState);
  }

  Future<List<ExposedCRDTPayload>> _processFrame(SPFrame spframe) async {
    List<ExposedCRDTPayload> exposedCrdtPayload = [];

    try {
      final (rawPayloads, _, _) = await groupContext.processFrame(
        frame: spframe.frame.writeToBuffer(),
      );

      final payloads = Payloads.fromBuffer(rawPayloads);
      for (final payload in payloads.payloads) {
        final (crdt, chatMessage) = FrameUtils.instance.exposePayload(payload);

        if (crdt != null) {
          exposedCrdtPayload.add(crdt);
        }

        if (chatMessage != null) {
          chatManager.addMessage(chatMessage);
        }
      }

      documentState.sequenceNumber = spframe.seqNum.toInt();

      return exposedCrdtPayload;
    } catch (e) {
      if (!isChangesAlreadyAppliedOrMerged(e)) {
        rethrow;
      }

      return [];
    }
  }

  Future<void> _sendChatFrame(List<int> messageBytes) async {
    final frame = await groupContext.createFrame(
      content: Payloads(
        payloads: [Payload(chat: ChatPayload(text: messageBytes))],
      ).writeToBuffer(),
    );

    await _db.updateGroupContextDocumentState(
      id: documentState.id,
      parts: await groupContext.asParts(),
    );

    await GroupApiClient.instance.sendFrame(
      groupId: documentState.id,
      frame: frame,
    );
  }

  Future<void> _sendCrdtFrame(
    String md,
    List<ExposedCRDTPayload> buffer,
  ) async {
    final forkedDocument = documentState.crdt.fork();
    forkedDocument.setActorId(
      uuid: AccountSecureStorage.instance.account.actorId,
    );
    EditorAutomergeUtils.instance.toDoc(md, forkedDocument);
    forkedDocument.commit();

    _syncDocumentWithCrdt(
      DocumentState(
        id: 'forked-doc-id',
        crdt: forkedDocument,
        createdAt: DateTime.now(),
        groupContextParts: GroupContextParts.empty(),
      ),
      buffer,
    );

    final saveIncremential = forkedDocument.saveIncremental();

    final frame = await groupContext.createFrame(
      content: Payloads(
        payloads: [
          Payload(crdt: CRDTPayload(incrementalChange: saveIncremential)),
        ],
      ).writeToBuffer(),
    );

    await _db.updateGroupContextDocumentState(
      id: documentState.id,
      parts: await groupContext.asParts(),
    );

    await GroupApiClient.instance.sendFrame(
      groupId: documentState.id,
      frame: frame,
    );

    documentState.crdt.loadIncremental(bytes: saveIncremential);
  }

  Future<void> _sendJoinGroupFrame(Account user) async {
    logger.info('Sending join group frame..');
    final frame = await groupContext.joinGroupAs(
      user: BUser(name: user.name, publicKey: user.keypair.rawPublicKey),
    );

    await _db.updateGroupContextDocumentState(
      id: documentState.id,
      parts: await groupContext.asParts(),
    );

    await GroupApiClient.instance.sendFrame(
      groupId: documentState.id,
      frame: frame,
    );
    logger.info('Sent join group frame');
  }
}

extension SyncModelHelpers on SyncModel {
  void _emitCorruptedEvent() {
    if (!_corrupedEvent.isClosed) {
      _corrupedEvent.add(corrupted);
    }
  }

  void _emitRemovedFromGroupEvent() {
    if (!_removedFromGroupEvent.isClosed) {
      _removedFromGroupEvent.add(true);
    }
  }

  void _emitCrdtUpdatesEvent() {
    if (!_crdtUpdatesEvent.isClosed) {
      _crdtUpdatesEvent.add(documentState.crdt);
    }
  }

  void _emitGroupInfoUpdatesEvent() {
    if (!_groupInfoUpdatesEvent.isClosed) {
      _groupInfoUpdatesEvent.add(true);
    }
  }
}

void _syncDocumentWithCrdt(
  DocumentState document,
  List<ExposedCRDTPayload> payloads,
) {
  logger.debug('Number of crdt payloads to apply: ${payloads.length}');

  logger.debug(
    'Document state before applying crdt: ID  ${document.id} ${document.crdt.getBlocks()}',
  );
  for (final payload in payloads) {
    switch (payload.kind) {
      case ExposedCRDTPayloadKind.incrementalChange:
        final incrementalChange = payload.crdt.incrementalChange;
        document.crdt.loadIncremental(bytes: incrementalChange);
      default:
    }
  }
  logger.debug(
    'Document state after applying crdt: ID ${document.id} ${document.crdt.getBlocks()}',
  );
}
