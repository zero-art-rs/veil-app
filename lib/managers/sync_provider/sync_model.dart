import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:async_queue/async_queue.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/managers/chat/chat_manager.dart';
import 'package:veil/managers/contacts_manager.dart';
import 'package:veil/managers/sharing/deeplink_manager.dart';
import 'package:veil/managers/sync_provider/sync_buffer.dart';
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
  final Document document;
  final BGroupContext groupContext;
  final ChatManager chatManager;
  StreamSubscription<SSEModel>? listener;
  final _db = DB.instance;

  final _crdtBuffer = LockedBuffer<ExposedCRDTPayload>();
  final _processQueue = AsyncQueue();
  final _sendQueue = AsyncQueue();

  bool bufferFrames = true;
  bool corrupted = false;
  get isLocal => document.localOnly;

  final _corrupedEvent = StreamController<bool>.broadcast();
  final _groupInfoUpdatesEvent = StreamController<bool>.broadcast();
  final _crdtUpdatesEvent = StreamController<BAutoCommit>.broadcast();
  final _removedFromGroupEvent = StreamController<bool>.broadcast();
  final _isProcessing = StreamController<bool>.broadcast();

  Stream<bool> get corruptedEvent => _corrupedEvent.stream;
  Stream<bool> get groupInfoUpdateEvent => _groupInfoUpdatesEvent.stream;
  Stream<BAutoCommit> get crdtUpdatesEvent => _crdtUpdatesEvent.stream;
  Stream<bool> get removedFromGroupEvent => _removedFromGroupEvent.stream;
  Stream<bool> get isProcessing => _isProcessing.stream;

  String _previousGroupInfoHash = '';

  SyncModel({
    required this.document,
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
        document.automergeDoc.loadIncremental(
          bytes: crdt.crdt.incrementalChange,
        );
      case ExposedCRDTPayloadKind.fullDocument:
        if (!allowFullDocument) return;
        logger.d('Received crdt full document');
        document.automergeDoc = BAutoCommit.load(data: crdt.crdt.fullDocument);
    }
  }

  void listenProcess() {
    _processQueue.addQueueListener((e) {
      if (_isProcessing.isClosed) return;
      _isProcessing.add(e.currentQueueSize != 0 && _sendQueue.size != 0);
    });

    _sendQueue.addQueueListener((e) {
      if (_isProcessing.isClosed) return;
      _isProcessing.add(e.currentQueueSize != 0 && _processQueue.size != 0);
    });
  }

  Future<void> synchronizeInitially({bool allowFullDocument = false}) async {
    logger.d(
      'Document sequence number before polling: ${document.sequenceNumber}',
    );
    logger.d(
      'Document epoch before polling: ${(await groupContext.epoch()).toInt()}',
    );

    while (true) {
      final signature = await groupContext.signWithTk(
        groupId: document.id,
        nonce: [0],
      );

      final result = await GroupApiClient.instance.getFrames(
        epoch: (await groupContext.epoch()).toInt(),
        groupId: document.id,
        signature: base64UrlEncode(signature),
        nonce: base64UrlEncode([0]),
        messageSequenceNumber: document.sequenceNumber,
      );

      if (result.spFrames.first.seqNum.toInt() == document.sequenceNumber) {
        break;
      }

      for (final spFrame in result.spFrames.reversed) {
        final crdtList = await _processFrame(spFrame);

        for (final crdt in crdtList) {
          _handleCrdt(crdt, allowFullDocument);
        }
      }

      await _db.updateDocument(
        doc: document,
        parts: await groupContext.asParts(),
      );
    }

    logger.d(
      'Document sequence number after polling: ${document.sequenceNumber}',
    );
    logger.d(
      'Document epoch after polling: ${(await groupContext.epoch()).toInt()}',
    );
  }

  Future<void> dispose() async {
    _processQueue.clear();
    _sendQueue.clear();
    await listener?.cancel();
    await _removedFromGroupEvent.close();
    await _groupInfoUpdatesEvent.close();
    await _crdtUpdatesEvent.close();
    await _isProcessing.close();
    logger.i('Sync provider disposed');
  }
}

extension SyncModelHandle on SyncModel {
  void bufferizeFrames() async {
    _processQueue.addJob(() async {
      logger.i('Change process frames to buffer mode');
      bufferFrames = true;
    });

    await _processQueue.start();
  }

  Future<void> applyBufferedFrames() async {
    _processQueue.addJob(() async {
      final snapshot = await _crdtBuffer.snapshot();
      await applyCrdtListOperation(snapshot);
      await _crdtBuffer.removeWhere((e) => snapshot.contains(e));
      _crdtUpdatesEvent.add(document.automergeDoc);
      bufferFrames = false;
      logger.i('Change process frames to process mode');
    });

    await _processQueue.start();
  }
}

extension SyncModelProcessOperations on SyncModel {
  Future<void> markAsCorrupted() async {
    logger.i('Highlighting corrupted document..');

    corrupted = true;
    _corrupedEvent.add(corrupted);
    await dispose();
    logger.i('Corrupted document highlighted');
  }

  Future<void> processFrame(SPFrame spframe) async {
    _processQueue.addJob(() async {
      logger.i('Received frame, processing..');
      logger.d('Received frame, frame epoch: ${spframe.frame.frame.epoch}..');
      logger.d('Received frame, frame seqNum: ${spframe.seqNum}..');

      _previousGroupInfoHash = sha256
          .convert(groupContext.groupInfo())
          .toString();

      final crdtList = await _processFrame(spframe);

      final currentGroupInfoHash = sha256
          .convert(groupContext.groupInfo())
          .toString();

      if (currentGroupInfoHash != _previousGroupInfoHash &&
          !_groupInfoUpdatesEvent.isClosed) {
        logger.i('Group info changed, sending update..');
        _groupInfoUpdatesEvent.add(true);
      }

      if (bufferFrames) {
        logger.d('Buffering crdt frames...');
        for (final payload in crdtList) {
          await _crdtBuffer.push(payload);
        }
      } else {
        logger.d('Applying crdt frames...');
        final snapshot = await _crdtBuffer.snapshot();
        snapshot.addAll(crdtList);
        await applyCrdtListOperation(snapshot);
        await _crdtBuffer.removeWhere((e) => snapshot.contains(e));
        _crdtUpdatesEvent.add(document.automergeDoc);
      }
    });

    try {
      await _processQueue.start();
    } catch (e) {
      if (isUserRemovedError(e)) {
        logger.i('User removed from group, making local only');
        _removedFromGroupEvent.add(true);
        await disableNetworkSyncOperation();
      } else {
        rethrow;
      }
    }
  }
}

extension SyncModelSendOperations on SyncModel {
  Future<void> leaveGroup() async {
    final opExecutionStream = StreamController<bool>();

    _sendQueue.addJob(() async {
      try {
        logger.i('Sending leave group frame..');
        final frame = await groupContext.leaveGroup();
        await GroupApiClient.instance.sendFrame(
          groupId: document.id,
          frame: frame,
        );
        logger.i('Sent leave group frame');

        await _db.updateDocument(
          doc: document,
          parts: await groupContext.asParts(),
        );

        opExecutionStream.add(true);
      } catch (e) {
        logger.e('Failed to send leave group frame: $e');
        _sendQueue.retry();
      }
    }, retryTime: 3);

    _sendQueue.start();
    await opExecutionStream.stream.first;
  }

  Future<void> sendCrdtFrame(String md) async {
    _sendQueue.addJob(() async {
      try {
        logger.i('Sending crdt frame..');
        final snapshot = await _crdtBuffer.snapshot();
        await _sendCrdtFrame(md, snapshot);
        await _crdtBuffer.removeWhere((e) => snapshot.contains(e));
        _crdtUpdatesEvent.add(document.automergeDoc);
        logger.i('Sent crdt frame');
      } catch (e) {
        logger.e('Failed to send crdt frame: $e');
        _sendQueue.retry();
      }
    }, retryTime: 3);

    await _sendQueue.start();
  }

  Future<void> sendChatFrame(List<int> messageBytes) async {
    _sendQueue.addJob(() async {
      await _sendChatFrame(messageBytes);
    });

    await _sendQueue.start();
  }

  Future<void> updateGroupName({required String name}) async {
    _sendQueue.addJob(() async {
      logger.i('Creating change group frame...');
      final frame = await groupContext.changeGroup(name: name);

      logger.i('Sending change group frame...');
      await GroupApiClient.instance.sendFrame(
        groupId: document.id,
        frame: frame,
      );
      logger.i('Change group frame was sent');
    });

    await _sendQueue.start();
  }

  Future<void> updateUserName({required String name}) async {
    _sendQueue.addJob(() async {
      logger.i('Creating change user frame...');
      final frame = await groupContext.changeUser(name: name);

      logger.i('Sending change user frame...');
      await GroupApiClient.instance.sendFrame(
        groupId: document.id,
        frame: frame,
      );
      logger.i('Change user frame was sent');
    });

    await _sendQueue.start();
  }

  Future<String> createIdentifiedMemberLink({required Contact contact}) async {
    final inviteLinkStream = StreamController<String>();

    _sendQueue.addJob(() async {
      try {
        logger.i('Creating identified member invite..');
        final firstSpk = contact.spks.firstOrNull;
        final spkPublicKey = firstSpk != null
            ? Uint8List.fromList(firstSpk)
            : null;

        logger.i('Spk to use apply: $spkPublicKey');

        final payload = Payload(
          crdt: CRDTPayload(fullDocument: document.automergeDoc.save()),
        );

        logger.i('Creating identified invite frame');
        final (frame, invite) = await groupContext.addIdentifiedMember(
          identityPublicKey: contact.account.rawPublicKey,
          spkPublicKey: spkPublicKey,
          content: Payloads(payloads: [payload]).writeToBuffer(),
        );

        logger.i('Sending identified invite frame');
        await GroupApiClient.instance.sendFrame(
          groupId: document.id,
          frame: frame,
        );
        logger.i('Identified invite frame sent');

        final inviteLink = DeeplinkManager.instance.buildInvite(invite);

        if (spkPublicKey != null) {
          logger.i('Removing spk contact spk..');
          await ContactsManager.instance.removeSpk(
            contact.account.actorId,
            spkPublicKey.toList(),
          );
        }

        inviteLinkStream.add(inviteLink);
      } catch (e) {
        logger.e('Failed to invite member: $e');
        _sendQueue.retry();
      }
    }, retryTime: 3);

    await _sendQueue.start();

    return await inviteLinkStream.stream.first;
  }

  Future<String> createUnidentifiedMemberInviteLink() async {
    final inviteLinkStream = StreamController<String>();

    _sendQueue.addJob(() async {
      try {
        logger.i('Creating unidentified member invite..');
        final secretKey = SecretManager.intance.generateSecretKey();

        final payloads = Payloads(
          payloads: [
            Payload(
              crdt: CRDTPayload(fullDocument: document.automergeDoc.save()),
            ),
          ],
        ).writeToBuffer();

        logger.i('Creating unidentified invite frame..');
        final (frame, invite) = await groupContext.addUnidentifiedMember(
          secretKey: secretKey,
          content: payloads,
        );

        logger.i('Sending unidentified invite frame...');
        await GroupApiClient.instance.sendFrame(
          groupId: document.id,
          frame: frame,
        );

        final inviteLink = DeeplinkManager.instance.buildInvite(invite);

        inviteLinkStream.add(inviteLink);
      } catch (e) {
        logger.e('Failed to create invite link: $e');
        _sendQueue.retry();
      }
    }, retryTime: 3);

    await _sendQueue.start();

    return await inviteLinkStream.stream.first;
  }

  Future<void> removeMember({required String actorId}) async {
    _sendQueue.addJob(() async {
      logger.i('Removing member in group context..');
      final frame = await groupContext.removeMember(
        userId: actorId,
        content: [],
      );

      logger.i('Sending remove member frame...');
      await GroupApiClient.instance.sendFrame(
        groupId: document.id,
        frame: frame,
      );

      logger.i('Remove member frame sent');
    });

    await _sendQueue.start();
  }

  Future<void> sendJoinGroupFrame(Account user) async {
    _sendQueue.addJob(() async {
      try {
        await _sendJoinGroupFrame(user);
      } catch (e) {
        logger.e('Failed to send join group frame: $e');
        _sendQueue.retry();
      }
    }, retryTime: -1);

    await _sendQueue.start();
  }
}

extension SyncModelOperations on SyncModel {
  Future<void> applyCrdtListOperation(List<ExposedCRDTPayload> payloads) async {
    logger.i('Applying crdt list..');
    if (payloads.isEmpty) {
      logger.i('No crdt payload list to apply');
      return;
    }
    _syncDocumentWithCrdt(document, payloads);

    await _db.updateDocument(
      doc: document,
      parts: await groupContext.asParts(),
    );

    logger.i('Applied crdt list');
  }

  Future<void> disableNetworkSyncOperation() async {
    await listener?.cancel();
    document.localOnly = true;

    LocalStateUtils.instance.makeDocumentLocal(document);
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

      document.sequenceNumber = spframe.seqNum.toInt();

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

    await GroupApiClient.instance.sendFrame(groupId: document.id, frame: frame);
  }

  Future<void> _sendCrdtFrame(
    String md,
    List<ExposedCRDTPayload> buffer,
  ) async {
    final forkedDocument = document.automergeDoc.fork();
    forkedDocument.setActorId(
      uuid: AccountSecureStorage.instance.account.actorId,
    );
    EditorAutomergeUtils.instance.toDoc(md, forkedDocument);
    forkedDocument.commit();

    _syncDocumentWithCrdt(
      Document(
        id: 'forked-doc-id',
        automergeDoc: forkedDocument,
        createdAt: DateTime.now(),
        groupContextParts: GroupContextParts.empty(),
      ),
      buffer,
    );

    final saveIncremential = forkedDocument.saveIncremental();

    await GroupApiClient.instance.sendFrame(
      groupId: document.id,
      frame: await groupContext.createFrame(
        content: Payloads(
          payloads: [
            Payload(crdt: CRDTPayload(incrementalChange: saveIncremential)),
          ],
        ).writeToBuffer(),
      ),
    );

    document.automergeDoc.loadIncremental(bytes: saveIncremential);
  }

  Future<void> _sendJoinGroupFrame(Account user) async {
    logger.i('Sending join group frame..');
    final frame = await groupContext.joinGroupAs(
      user: BUser(name: user.name, publicKey: user.keypair.rawPublicKey),
    );

    await GroupApiClient.instance.sendFrame(groupId: document.id, frame: frame);
    logger.i('Sent join group frame');
  }
}

void _syncDocumentWithCrdt(
  Document document,
  List<ExposedCRDTPayload> payloads,
) {
  logger.d('Number of crdt payloads to apply: ${payloads.length}');

  logger.d(
    'Document state before applying crdt: ID  ${document.id} ${document.automergeDoc.getBlocks()}',
  );
  for (final payload in payloads) {
    switch (payload.kind) {
      case ExposedCRDTPayloadKind.incrementalChange:
        final incrementalChange = payload.crdt.incrementalChange;
        document.automergeDoc.loadIncremental(bytes: incrementalChange);
      default:
    }
  }
  logger.d(
    'Document state after applying crdt: ID ${document.id} ${document.automergeDoc.getBlocks()}',
  );
}
