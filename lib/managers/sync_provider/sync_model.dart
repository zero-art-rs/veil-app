import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:queue/queue.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:veil/managers/chat/hive_chat_controller.dart';
import 'package:veil/managers/svces_status_listener.dart';
import 'package:veil/managers/sync_provider/centrifugo_listener.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/managers/chat/chat_manager.dart';
import 'package:veil/managers/contacts_manager.dart';
import 'package:veil/managers/sharing/deeplink_manager.dart';
import 'package:veil/managers/sync_provider/buffer.dart';
import 'package:veil/managers/queues_listener.dart';
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

import '../../main.dart' as main;

enum SyncModelStateMode { local, network, corrupted }

enum SyncModelMode { read, write }

/// `SyncModel` represents a single document synchronization state and operations
/// It handles its own state and sharing with it via streams
class SyncModel {
  final Talker? _logger;
  final DocumentState documentState;
  final BGroupContext groupContext;
  late final ChatManager chatManager;
  CentrifugoListener? _centrifugoListener;
  final _db = DB.instance;
  final _crdtBuffer = LockedBuffer<ExposedCRDTPayload>();

  /// For test purposes
  Talker get logger => _logger ?? main.logger;

  /// Queue for the processing incoming frames from centrifugo
  final _processQueue = Queue();

  /// Queue for the sending self-created frames to the server
  final _sendQueue = Queue();

  /// Queue for the handling state
  final _stateQueue = Queue();

  /// Listener for the busy state of the queues
  late final QueuesListener _queuesProcessListener = QueuesListener(
    streams: [_processQueue.remainingItems, _sendQueue.remainingItems],
  );

  /// Listener for network status changes
  StreamSubscription<NetworkStatus>? _networkStatusListener;
  StreamSubscription? _centrifugoDisconnectedListener;

  /// Indicates current state
  SyncModelStateMode _state = SyncModelStateMode.local;

  /// Indicates current mode
  SyncModelMode _mode = SyncModelMode.read;

  /// Handle state in UI with
  get isLocal => documentState.isLocal;
  bool corrupted = false;
  bool isSyncing = false;

  final _corrupedEvent = StreamController<bool>.broadcast();
  final _groupInfoUpdatesEvent = StreamController<bool>.broadcast();
  final _crdtUpdatesEvent = StreamController<BAutoCommit>.broadcast();
  final _removedFromGroupEvent = StreamController<bool>.broadcast();
  final _synchronizingEvent = StreamController<bool>.broadcast();

  Stream<bool> get synchronizingEvent => _synchronizingEvent.stream;
  Stream<bool> get corruptedEvent => _corrupedEvent.stream;
  Stream<bool> get groupInfoUpdateEvent => _groupInfoUpdatesEvent.stream;
  Stream<BAutoCommit> get crdtUpdatesEvent => _crdtUpdatesEvent.stream;
  Stream<bool> get removedFromGroupEvent => _removedFromGroupEvent.stream;
  Stream<bool> get isProcessing => _queuesProcessListener.isProcessing;

  /// Marker to track detection of group info changes for emitting `change group info` event
  String _previousGroupInfoHash = '';

  SyncModel({
    required this.documentState,
    required this.groupContext,
    Talker? logger,
  }) : _logger = logger;

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

extension SyncModelState on SyncModel {
  Future<void> setup({bool allowFullDocument = false}) async {
    _queuesProcessListener.listen();

    final hive = await Hive.openBox(documentState.id);
    final hiveChatController = HiveChatController(hive);
    chatManager = ChatManager(controller: hiveChatController);

    await setState(
      SyncModelStateMode.local,
      allowFullDocument: allowFullDocument,
    );

    if (!documentState.isLocal) {
      _setupNetworkListener();

      final networkStatus =
          NetworkStatusListener.instance.connectionStatus.value;

      if (networkStatus == NetworkStatus.connected) {
        await setState(SyncModelStateMode.network);
        if (_mode == SyncModelMode.read) await applyBufferedFrames();
      }
    }
  }

  /// Disposes the sync model
  /// * disableStateBroadcast - if true, state broadcast will be disabled
  /// * disableNetworkListener - if true, will not check internet connection and try to reconnect
  /// * cancelPendingTasks - if true, pending tasks in queues will be cancelled
  Future<void> clearState({
    bool disableStateBroadcast = false,
    bool disableNetworkListener = false,
    bool cancelPendingTasks = false,
  }) async {
    if (disableNetworkListener) {
      _networkStatusListener?.cancel();
    }

    logger.debug('Dispose centrifugo listener..');
    await _centrifugoListener?.dispose();
    await _centrifugoDisconnectedListener?.cancel();

    logger.debug('Cleaning up queues and queues listener...');
    if (cancelPendingTasks) {
      _processQueue.cancel();
      _sendQueue.cancel();
      _queuesProcessListener.dispose();
    }

    logger.debug(
      'Waiting for the cancelling pending works... ${_processQueue.remainingItemCount}, ${_sendQueue.remainingItemCount}',
    );
    if (_processQueue.remainingItemCount > 0) {
      await _processQueue.onComplete;
    }

    if (_sendQueue.remainingItemCount > 0) {
      await _sendQueue.onComplete;
    }

    // Apply remaining buffered crdt payload list
    final snapshot = await _crdtBuffer.snapshot();
    if (snapshot.isNotEmpty) {
      logger.debug('Applying remaining buffered frames before dispose..');
      await applyCrdtListOperation(snapshot);
      await _crdtBuffer.removeWhere((e) => snapshot.contains(e));
    }

    // Closing state broadcast streams
    if (disableStateBroadcast) {
      logger.debug('Closing state broadcast streams..');
      await _removedFromGroupEvent.close();
      await _groupInfoUpdatesEvent.close();
      await _crdtUpdatesEvent.close();
    }

    logger.debug('Sync provider disposed');
  }

  void _setupNetworkListener() {
    _networkStatusListener = NetworkStatusListener.instance.connectionStatus
        .skip(1)
        .listen((e) async {
          await setState(
            e == NetworkStatus.connected
                ? SyncModelStateMode.network
                : SyncModelStateMode.local,
          );
        });
  }

  Future<void> setState(
    SyncModelStateMode mode, {
    bool allowFullDocument = false,
  }) async {
    await _stateQueue.add(() async {
      switch (mode) {
        case SyncModelStateMode.local:
          await _setupLocal();
        case SyncModelStateMode.network:
          _emitIsSyncingEvent(true);
          try {
            await _setupNetwork(allowFullDocument: allowFullDocument);
          } catch (e, st) {
            logger.error(
              'Failed to initially synchronize document, highlighting document as corrupted',
              e,
              st,
            );

            await _markAsCorrupted();
          } finally {
            _emitIsSyncingEvent(false);
          }
        case SyncModelStateMode.corrupted:
          await _markAsCorrupted();
      }
    });
  }

  Future<void> _setupLocal() async {
    _state = SyncModelStateMode.local;
    await _centrifugoListener?.dispose();
    await _centrifugoDisconnectedListener?.cancel();
    _centrifugoDisconnectedListener = null;
    _centrifugoListener = null;
    if (_processQueue.remainingItemCount > 0) {
      await _processQueue.onComplete;
    }
  }

  /// Synchronizes local state with current document state from server
  Future<void> _setupNetwork({bool allowFullDocument = false}) async {
    final challenge = await GroupApiClient.instance.getChallenge(
      documentState.id,
    );

    final jwt = await GroupApiClient.instance.getCentrifugoJWT(
      groupId: documentState.id,
      epoch: (await groupContext.epoch()).toInt(),
      proof: base64Encode(
        await groupContext.signChallenge(challenge: base64Decode(challenge)),
      ),
      challenge: challenge,
    );

    await _processQueue.add(() async {
      final listener = CentrifugoListener(
        processCallback: (response) async {
          if (response.data.isEmpty) return;
          try {
            final rawJson = json.decode(response.data);
            if (rawJson['pub'] == null) return;

            logger.debug(
              'Centrifugo received data: ${response.data}, event: ${response.event}, id: ${response.id}',
            );

            final frameBytes = base64Decode(rawJson['pub']['data'].toString());
            final frame = SPFrame.fromBuffer(frameBytes);
            await processFrame(frame);
          } catch (e, st) {
            logger.error(
              'Failed to process frame, highlighting document as corrupted',
              e,
              st,
            );

            await setState(SyncModelStateMode.corrupted);
          }
        },
      );

      _setCentrifugoListener(listener, jwtToken: jwt);
      await _pollFrames(allowFullDocument: allowFullDocument);
    });

    if (_mode == SyncModelMode.read) {
      await sendLocalCrdtChanges();
    }

    _state = SyncModelStateMode.network;
  }

  Future<void> _resync() async {
    final networkStatus = NetworkStatusListener.instance.connectionStatus.value;

    logger.info('Resyncing document..');
    if (networkStatus == NetworkStatus.connected) {
      await setState(SyncModelStateMode.network);
    } else {
      await setState(SyncModelStateMode.local);
    }
    logger.info('Document resynced');
  }

  void _setCentrifugoListener(
    CentrifugoListener centrifugoListener, {
    required String jwtToken,
  }) {
    _centrifugoListener = centrifugoListener;
    _centrifugoListener?.connect(jwtToken);

    // Once we receive a reconnection event, centrifugoListener is alredy disconnected
    _centrifugoDisconnectedListener = _centrifugoListener?.disconnectedEvent
        .listen((_) async {
          await _resync();
        });
  }

  Future<void> _pollFrames({bool allowFullDocument = false}) async {
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
          'Current processing frame sequence number: ${spFrame.seqNum.toInt()}',
        );

        final crdtList = await _processFrame(spFrame);

        _applyCrdtPayloadList(
          document: documentState,
          payloads: crdtList,
          allowFullDocument: allowFullDocument,
        );
      }
    }

    await _db.updateDocumentState(
      documentState: documentState,
      groupContextParts: await groupContext.asParts(),
    );

    logger.debug(
      'Document epoch after polling: ${(await groupContext.epoch()).toInt()}',
    );
    logger.debug(
      'Document sequence number after polling: ${documentState.sequenceNumber}',
    );
  }
}

extension SyncModelHandle on SyncModel {
  Future<void> selectMode(SyncModelMode mode) async {
    try {
      await _processQueue.add(() async {
        logger.info('Change process frames to buffer mode');
        _mode = mode;
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

        if (_mode == SyncModelMode.write) {
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
  Future<void> sendLeaveGroupFrame() async {
    try {
      return await _write(
        operation: () async {
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
        },
      );
    } on QueueCancelledException {
      logger.debug('Send queue cancelled, leave group frame not sent');
    }
  }

  Future<void> sendCrdtFrame(String md, {int maxAttempts = 3}) async {
    try {
      return await _write(
        maxAttempts: maxAttempts,
        operation: () async {
          logger.info('Sending crdt frame..');

          final snapshot = await _crdtBuffer.snapshot();
          EditorAutomergeUtils.instance.toDoc(md, documentState.crdt);
          documentState.crdt.commit();

          _applyCrdtPayloadList(document: documentState, payloads: snapshot);

          final saveIncremential = documentState.crdt.saveIncremental();
          final _ = await _db.insertLocalCrdtChange(
            documentId: documentState.id,
            data: saveIncremential,
          );

          if (_state == SyncModelStateMode.network) {
            final localChanges = await _db.getLocalCrdtChanges(
              documentState.id,
            );

            logger.debug('Crdt changes to send : ${localChanges.length}');
            await _sendCrdtFrameList(
              localChanges.map((e) => e.content).toList(),
            );

            await _db.deleteLocalCrdtChanges(
              documentState.id,
              localChanges.map((e) => e.id).toList(),
            );
          }

          await _crdtBuffer.removeWhere((e) => snapshot.contains(e));
          logger.info('Sent crdt frame');
        },
      );
    } on QueueCancelledException {
      logger.debug('Send queue cancelled, crdt frame not sent');
    }
  }

  Future<void> sendLocalCrdtChanges() async {
    try {
      return await _write(
        operation: () async {
          logger.info('Sending local crdt changes..');
          final localChanges = await _db.getLocalCrdtChanges(documentState.id);

          logger.debug('Crdt changes to send : ${localChanges.length}');
          await _sendCrdtFrameList(localChanges.map((e) => e.content).toList());

          await _db.deleteLocalCrdtChanges(
            documentState.id,
            localChanges.map((e) => e.id).toList(),
          );

          logger.info('Sent local crdt changes');
        },
      );
    } on QueueCancelledException {
      logger.debug('Send queue cancelled, crdt frame not sent');
    }
  }

  Future<void> sendChatFrame(List<int> messageBytes) async {
    if (_state == SyncModelStateMode.local) {
      throw SyncModelSendError('Cannot create invite in local mode');
    }

    try {
      return await _write(
        operation: () async {
          await _sendChatFrame(messageBytes);
        },
      );
    } on QueueCancelledException {
      logger.debug('Send queue cancelled, chat frame not sent');
    }
  }

  Future<void> updateGroupName({required String name}) async {
    try {
      await _write(
        operation: () async {
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
        },
      );
    } on QueueCancelledException {
      logger.debug('Send queue cancelled, update group name frame not sent');
    }
  }

  Future<void> updateUserName({required String name}) async {
    try {
      return await _write(
        maxAttempts: 1,
        operation: () async {
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
        },
      );
    } on QueueCancelledException {
      logger.debug('Send queue cancelled, change user frame not sent');
    }
  }

  Future<String> createIdentifiedMemberLink({required Contact contact}) async {
    if (_state == SyncModelStateMode.local) {
      throw SyncModelSendError('Cannot create invite in local mode');
    }

    try {
      return await _write(
        operation: () async {
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
        },
      );
    } on QueueCancelledException {
      logger.debug('Send queue cancelled, identified invite not sent');
      return "";
    }
  }

  Future<String> createUnidentifiedMemberInviteLink() async {
    if (_state == SyncModelStateMode.local) {
      throw SyncModelSendError('Cannot create invite in local mode');
    }

    try {
      return await _write(
        operation: () async {
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
        },
      );
    } on QueueCancelledException {
      logger.debug('Send queue cancelled, unidentified invite not sent');
      return "";
    }
  }

  Future<void> removeMember({required String actorId}) async {
    try {
      await _write(
        operation: () async {
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
        },
      );
    } on QueueCancelledException {
      logger.debug('Send queue cancelled, remove member frame not sent');
    }
  }

  Future<void> sendJoinGroupFrame(Account user) async {
    try {
      await _write(
        operation: () async {
          logger.info('Sending join group frame..');
          return await _sendJoinGroupFrame(user);
        },
      );
    } on QueueCancelledException {
      logger.debug('Send queue cancelled, join group frame not sent');
    }
  }

  Future<T> _write<T>({
    int maxAttempts = 3,
    bool isLocal = false,
    required Future<T> Function() operation,
  }) async {
    return await _sendQueue.add(() async {
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          return await operation();
        } catch (e) {
          if (attempt == maxAttempts) {
            rethrow;
          } else {
            logger.warning(
              'Failed to perform send operation, attempt: $attempt, max attempts: $maxAttempts, retrying..: $e',
            );
          }
        }
      }

      throw Exception('Unreachable code');
    });
  }
}

extension SyncModelOperations on SyncModel {
  Future<void> _markAsCorrupted() async {
    logger.info('Marking document as corrupted..');

    _emitCorruptedEvent();
    await clearState(
      disableNetworkListener: true,
      disableStateBroadcast: true,
      cancelPendingTasks: true,
    );

    logger.info('Document marked as corrupted');
  }

  Future<void> applyCrdtListOperation(List<ExposedCRDTPayload> payloads) async {
    logger.info('Applying crdt list..');

    _applyCrdtPayloadList(document: documentState, payloads: payloads);

    await _db.updateDocumentState(
      documentState: documentState,
      groupContextParts: await groupContext.asParts(),
    );

    logger.info('Applied crdt list');
  }

  Future<void> disableNetworkSyncOperation() async {
    await clearState();
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

  Future<void> _sendCrdtFrameList(List<Uint8List> data) async {
    final frame = await groupContext.createFrame(
      content: Payloads(
        payloads: data
            .map((e) => Payload(crdt: CRDTPayload(incrementalChange: e)))
            .toList(),
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
  void _emitIsSyncingEvent(bool isSyncing) {
    if (!_synchronizingEvent.isClosed) {
      this.isSyncing = isSyncing;
      _synchronizingEvent.add(isSyncing);
    }
  }

  void _emitCorruptedEvent() {
    if (!_corrupedEvent.isClosed) {
      corrupted = true;
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

  void _applyCrdtPayloadList({
    required DocumentState document,
    required List<ExposedCRDTPayload> payloads,
    bool allowFullDocument = false,
  }) {
    logger.debug('Number of CRDT payloads to apply: ${payloads.length}');
    logger.debug(
      'Document state BEFORE applying CRDT: ID ${document.id} ${document.crdt.getBlocks()}',
    );

    for (final payload in payloads) {
      switch (payload.kind) {
        case ExposedCRDTPayloadKind.incrementalChange:
          final incremental = payload.crdt.incrementalChange;
          document.crdt.loadIncremental(bytes: incremental);
          break;

        case ExposedCRDTPayloadKind.fullDocument:
          if (!allowFullDocument) {
            continue;
          }
          logger.debug('Received CRDT full document for ${document.id}');
          document.crdt = BAutoCommit.load(data: payload.crdt.fullDocument);
          break;
      }
    }

    if (payloads.isNotEmpty) {
      _emitCrdtUpdatesEvent();
    }

    logger.debug(
      'Document state AFTER applying CRDT: ID ${document.id} ${document.crdt.getBlocks()}',
    );
  }
}
