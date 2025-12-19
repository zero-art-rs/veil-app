import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:queue/queue.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:uuid/v4.dart';
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
import 'package:veil/managers/sync_provider/events.dart';
import 'package:veil/managers/sync_provider/local_crdt_storage.dart';
import 'package:veil/managers/sync_provider/logger/logger.dart';
import 'package:veil/managers/sync_provider/sync_model_errors.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models/account.dart';
import 'package:veil/storage/models/document_state.dart';
import 'package:veil/storage/sqlite/consts.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/editor_automerge.dart';
import 'package:veil/utils/group_context_factory.dart';
import 'package:veil/utils/payload.dart';
import 'package:veil/utils/secret_factory.dart';

enum SyncModelStateMode { local, network, corrupted, init }

enum SyncModelMode { read, write }

/// `SyncModel` represents a single document synchronization state and operations
/// It handles its own state and sharing with it via streams
class SyncModel {
  final SyncModelLogger? logger;
  final Account account;
  final DocumentState documentState;
  final BGroupContext groupContext;
  final bool saveToDb;
  final LocalCrdtStorage _localCrdtStorage;
  late final ChatManager chatManager;
  CentrifugoListener? _centrifugoListener;
  final _db = DB.instance;
  final _crdtBuffer = LockedBuffer<ExposedCRDTPayload>();

  /// Queue for the processing incoming frames from centrifugo
  final _processQueue = Queue();

  /// Queue for the sending self-created frames to the server
  final _writeQueue = Queue();

  /// Queue for the handling state
  final _stateQueue = Queue();

  /// Listener for the busy state of the queues
  late final QueuesListener queuesProcessListener = QueuesListener(
    streams: [_processQueue.remainingItems, _writeQueue.remainingItems],
  );

  /// Listener for network status changes
  StreamSubscription<NetworkStatus>? _networkStatusListener;
  StreamSubscription? _centrifugoDisconnectedListener;

  /// Indicates current state
  SyncModelStateMode _state = SyncModelStateMode.init;

  /// Indicates current mode
  SyncModelMode _mode = SyncModelMode.read;

  /// Handle state in UI with
  get removedFromGroup => documentState.isLocal;
  bool corrupted = false;
  bool isSyncing = false;

  final _eventController = StreamController<SyncModelEvent>.broadcast();
  Stream<SyncModelEvent> get eventStream => _eventController.stream;

  /// Marker to track detection of group info changes for emitting `change group info` event
  String _previousGroupInfoHash = '';

  SyncModel({
    required this.documentState,
    required this.groupContext,
    required LocalCrdtStorage localCrdtStorage,
    this.logger,
    this.saveToDb = true,
    Account? account,
  }) : _localCrdtStorage = localCrdtStorage,
       account = account ?? AccountSecureStorage.instance.account;

  bool isUserInGroup() {
    return groupContext.retrieveGroupInfo().members.any(
      (e) => e.id == account.actorId,
    );
  }

  bool isChangingGroupMetaAllowed() {
    return groupContext
            .retrieveGroupInfo()
            .members
            .firstWhereOrNull((e) => e.id == account.actorId)
            ?.role
            .value ==
        ownerRole;
  }
}

extension SyncModelState on SyncModel {
  Future<void> setup({bool allowFullDocument = false}) async {
    logger?.stateLog('Start the setup of sync model');
    queuesProcessListener.listen();

    final hive = await Hive.openBox(documentState.id);
    final hiveChatController = HiveChatController(hive);
    chatManager = ChatManager(controller: hiveChatController);

    await setState(
      SyncModelStateMode.local,
      allowFullDocument: allowFullDocument,
    );

    if (!documentState.isLocal) {
      final _ = await NetworkStatusListener.instance.connectionStatus.any(
        (e) => e == NetworkStatus.connected,
      );

      _setupNetworkListener();

      await setState(
        SyncModelStateMode.network,
        allowFullDocument: allowFullDocument,
      );
      if (_mode == SyncModelMode.read) await applyBufferedFrames();
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

    logger?.stateLog('Dispose centrifugo listener..', level: LogLevel.debug);
    await _centrifugoListener?.dispose();
    await _centrifugoDisconnectedListener?.cancel();

    if (cancelPendingTasks) {
      logger?.stateLog(
        'Cleaning up queues and queues listener...',
        level: LogLevel.debug,
      );
      _processQueue.cancel();
      _writeQueue.cancel();
      queuesProcessListener.dispose();
    }

    logger?.stateLog(
      'Waiting for the cancelling pending works... process queue items: ${_processQueue.remainingItemCount}, write queue items: ${_writeQueue.remainingItemCount}',
      level: LogLevel.debug,
    );

    if (_processQueue.remainingItemCount > 0) {
      await _processQueue.onComplete;
    }

    if (_writeQueue.remainingItemCount > 0) {
      await _writeQueue.onComplete;
    }

    // Apply remaining buffered crdt payload list
    final snapshot = await _crdtBuffer.snapshot();
    if (snapshot.isNotEmpty) {
      logger?.stateLog(
        'Applying remaining buffered frames before dispose..',
        level: LogLevel.debug,
      );
      await applyCrdtListOperation(snapshot);
      await _crdtBuffer.removeWhere((e) => snapshot.contains(e));
    }

    // Closing state broadcast streams
    if (disableStateBroadcast) {
      logger?.stateLog(
        'Closing state broadcast stream..',
        level: LogLevel.debug,
      );
      await _eventController.close();
    }

    logger?.stateLog('Sync provider disposed', level: LogLevel.debug);
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
    SyncModelStateMode state, {
    bool allowFullDocument = false,
  }) async {
    if (state == _state) return;

    await _stateQueue.add(() async {
      switch (state) {
        case SyncModelStateMode.local:
          logger?.stateLog('Switching to local state');
          await _setupLocal();
          logger?.stateLog('Switched to local state');
        case SyncModelStateMode.network:
          try {
            logger?.stateLog('Switching to network state');
            _emitIsSyncingEvent(true);
            await _setupNetwork(allowFullDocument: allowFullDocument);
            logger?.stateLog('Switched to network state');
          } catch (e, st) {
            logger?.stateLog(
              'Failed to switch to network state: $e',
              level: LogLevel.error,
              stackTrace: st,
            );
            await _markAsCorrupted();
          } finally {
            _emitIsSyncingEvent(false);
          }
        case SyncModelStateMode.corrupted:
          logger?.stateLog('Switching to corrupted state');
          await _markAsCorrupted();
          logger?.stateLog('Switched to corrupted state');
        default:
          throw SyncModelInitError('Unreachable state');
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
        logger: logger,
        processCallback: (response) async {
          if (response.data.isEmpty) return;
          try {
            final rawJson = json.decode(response.data);
            if (rawJson['pub'] == null) return;

            logger?.centrifugoLog(
              'Centrifugo received data: ${response.data}, event: ${response.event}, id: ${response.id}',
              level: LogLevel.debug,
            );

            final frameBytes = base64Decode(rawJson['pub']['data'].toString());
            final frame = SPFrame.fromBuffer(frameBytes);
            await processFrame(frame);
          } catch (e, st) {
            logger?.centrifugoLog(
              'Failed to process frame, highlighting document as corrupted $e',
              stackTrace: st,
              level: LogLevel.error,
            );

            await setState(SyncModelStateMode.corrupted);
          }
        },
      );

      await _setCentrifugoListener(listener, jwtToken: jwt);
      await _pollFrames(allowFullDocument: allowFullDocument);
    });

    if (!isUserInGroup()) {
      await sendJoinGroupFrame(account);
    }

    if (_mode == SyncModelMode.read) {
      await sendLocalCrdtChanges();
    }

    _state = SyncModelStateMode.network;
  }

  Future<void> _resync() async {
    final networkStatus = NetworkStatusListener.instance.connectionStatus.value;

    logger?.modelLog('Resyncing document..');
    if (networkStatus == NetworkStatus.connected) {
      await setState(SyncModelStateMode.network);
    } else {
      await setState(SyncModelStateMode.local);
    }
    logger?.modelLog('Document resynced, current state: $_state');
  }

  Future<void> _setCentrifugoListener(
    CentrifugoListener centrifugoListener, {
    required String jwtToken,
  }) async {
    _centrifugoListener = centrifugoListener;

    final centrifugoLaunchedStreamController = StreamController<bool>();
    _centrifugoListener?.connect(
      jwtToken,
      connectionChecker: centrifugoLaunchedStreamController,
    );

    final status = await centrifugoLaunchedStreamController.stream.first;
    centrifugoLaunchedStreamController.close();

    if (!status) {
      throw SyncModelInitError('Failed to connect to Centrifugo');
    }

    _centrifugoDisconnectedListener = _centrifugoListener?.disconnectedEvent
        .listen((_) async {
          await _resync();
        });
  }

  Future<void> _pollFrames({bool allowFullDocument = false}) async {
    logger?.stateLog(
      'Document epoch before polling: ${(await groupContext.epoch()).toInt()}',
      level: LogLevel.debug,
    );
    logger?.stateLog(
      'Document sequence number before polling: ${documentState.sequenceNumber}',
      level: LogLevel.debug,
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
        messageSequenceNumber: documentState.sequenceNumber + 1,
      );

      if (result.spFrames.lastOrNull?.seqNum.toInt() ==
              documentState.sequenceNumber ||
          result.spFrames.lastOrNull == null) {
        break;
      }

      for (final spFrame in result.spFrames) {
        logger?.stateLog(
          'Current processing frame epoch: ${(spFrame.frame.frame.epoch).toInt()}',
          level: LogLevel.debug,
        );
        logger?.stateLog(
          'Current processing frame sequence number: ${spFrame.seqNum.toInt()}',
          level: LogLevel.debug,
        );

        final crdtList = await _processFrame(spFrame);

        _applyCrdtPayloadList(
          document: documentState,
          payloads: crdtList,
          allowFullDocument: allowFullDocument,
        );
      }
    }

    await _saveState();

    logger?.stateLog(
      'Document epoch after polling: ${(await groupContext.epoch()).toInt()}',
      level: LogLevel.debug,
    );
    logger?.stateLog(
      'Document sequence number after polling: ${documentState.sequenceNumber}',
      level: LogLevel.debug,
    );
  }
}

extension SyncModelHandle on SyncModel {
  Future<void> selectMode(SyncModelMode mode) async {
    try {
      await _processQueue.add(() async {
        _mode = mode;
      });
    } on QueueCancelledException {
      logger?.writeLog('Process queue cancelled', level: LogLevel.debug);
    }
  }

  Future<void> applyBufferedFrames() async {
    try {
      await _processQueue.add(() async {
        final snapshot = await _crdtBuffer.snapshot();
        await applyCrdtListOperation(snapshot);
        await _crdtBuffer.removeWhere((e) => snapshot.contains(e));
        logger?.writeLog(
          'Change process frames to process mode',
        ); // TODO: UPDATE LOG
      });
    } on QueueCancelledException {
      logger?.writeLog('Process queue cancelled');
    }
  }
}

extension SyncModelProcessOperations on SyncModel {
  Future<void> processFrame(SPFrame spframe) async {
    try {
      await _processQueue.add(() async {
        logger?.processLog(
          'Received frame, epoch: ${spframe.frame.frame.epoch}, seqNum: ${spframe.seqNum}, start processing..',
          level: LogLevel.debug,
        );

        _previousGroupInfoHash = sha256
            .convert(groupContext.groupInfo())
            .toString();

        final crdtList = await _processFrame(spframe);

        final currentGroupInfoHash = sha256
            .convert(groupContext.groupInfo())
            .toString();

        if (currentGroupInfoHash != _previousGroupInfoHash) {
          _emitGroupInfoUpdatesEvent(groupContext.retrieveGroupInfo());
        }

        if (_mode == SyncModelMode.write) {
          logger?.processLog('Buffering crdt frames..', level: LogLevel.debug);
          for (final payload in crdtList) {
            await _crdtBuffer.push(payload);
          }
        } else {
          logger?.processLog('Applying crdt frames..', level: LogLevel.debug);
          final snapshot = await _crdtBuffer.snapshot();
          snapshot.addAll(crdtList);
          await applyCrdtListOperation(snapshot);
          await _crdtBuffer.removeWhere((e) => snapshot.contains(e));
        }

        logger?.processLog(
          'Frame processed, epoch: ${spframe.frame.frame.epoch}, seqNum: ${spframe.seqNum}',
          level: LogLevel.debug,
        );
      });
    } on QueueCancelledException {
      logger?.processLog('Process queue cancelled', level: LogLevel.debug);
    } catch (e) {
      if (isUserRemovedError(e)) {
        logger?.processLog('User removed from group, making local only');
        _emitRemovedFromGroupEvent();
        await makeLocal();
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
          logger?.writeLog('Start leave group operation..');
          final frame = await groupContext.leaveGroup();
          await _saveGroupContext();
          logger?.writeLog('Sending leave group frame...');
          await GroupApiClient.instance.sendFrame(
            groupId: documentState.id,
            frame: frame,
          );
          logger?.writeLog('Leave group frame sent');
          await _saveState();
          logger?.writeLog('Finish leave group operation');
        },
      );
    } on QueueCancelledException {
      logger?.writeLog(
        'Send queue cancelled, leave group frame not sent',
        level: LogLevel.debug,
      );
    }
  }

  Future<void> sendCrdtFrame(String md, {int maxAttempts = 7}) async {
    try {
      return await _write(
        maxAttempts: maxAttempts,
        operation: () async {
          logger?.writeLog('Send crdt frame operation started');

          final snapshot = await _crdtBuffer.snapshot();
          EditorAutomergeUtils.instance.toDoc(md, documentState.crdt);
          documentState.crdt.commit();

          _applyCrdtPayloadList(document: documentState, payloads: snapshot);

          final saveIncremential = documentState.crdt.saveIncremental();

          await _localCrdtStorage.insertLocalCrdtChange(
            documentId: documentState.id,
            data: saveIncremential,
          );

          if (_state == SyncModelStateMode.network && isUserInGroup()) {
            logger?.writeLog('Sending crdt frame to server..');
            final localChanges = await _localCrdtStorage.getLocalCrdtChanges(
              documentId: documentState.id,
            );

            logger?.writeLog(
              'Crdt changes to send : ${localChanges.length}',
              level: LogLevel.debug,
            );
            await _sendCrdtFrameList(
              localChanges.map((e) => e.content).toList(),
            );
            logger?.writeLog('Crdt frame sent..');

            await _localCrdtStorage.deleteLocalCrdtChanges(
              documentId: documentState.id,
              ids: localChanges.map((e) => e.id).toList(),
            );
          } else {
            logger?.writeLog(
              'Crdt frame wasn\'t sent, user is not in group or mode is local',
            );
          }

          await _crdtBuffer.removeWhere((e) => snapshot.contains(e));
          logger?.writeLog('Sent crdt frame operation finished');
        },
      );
    } on QueueCancelledException {
      logger?.writeLog(
        'Send queue cancelled, crdt frame not sent',
        level: LogLevel.debug,
      );
    }
  }

  Future<void> sendLocalCrdtChanges() async {
    try {
      return await _write(
        operation: () async {
          logger?.writeLog('Send local crdt changes operation started');

          final localChanges = await _localCrdtStorage.getLocalCrdtChanges(
            documentId: documentState.id,
          );

          if (localChanges.isEmpty) {
            logger?.writeLog(
              'No local crdt changes to send, operation finished',
            );
            return;
          }

          if (isUserInGroup()) {
            logger?.writeLog(
              'Crdt changes to send : ${localChanges.length}',
              level: LogLevel.debug,
            );
            await _sendCrdtFrameList(
              localChanges.map((e) => e.content).toList(),
            );
            logger?.writeLog('Local crdt changes sent');

            await _localCrdtStorage.deleteLocalCrdtChanges(
              documentId: documentState.id,
              ids: localChanges.map((e) => e.id).toList(),
            );
          } else {
            logger?.writeLog(
              'Local crdt frames wasn\'t sent, user is not in group or mode is local',
            );
          }
        },
      );
    } on QueueCancelledException {
      logger?.writeLog(
        'Send queue cancelled, crdt frame not sent',
        level: LogLevel.debug,
      );
    }
  }

  Future<void> sendChatFrame(TextMessage message) async {
    if (_state == SyncModelStateMode.local) {
      throw SyncModelSendError('Cannot create invite in local mode');
    }

    if (!isUserInGroup()) {
      throw SyncModelSendError('User is not in group');
    }

    try {
      return await _write(
        operation: () async {
          logger?.writeLog('Send chat frame operation started');

          final json = jsonEncode(message);

          final frame = await groupContext.createFrame(
            content: Payloads(
              payloads: [Payload(chat: ChatPayload(text: utf8.encode(json)))],
            ).writeToBuffer(),
          );

          await _saveGroupContext();

          logger?.writeLog('Sending chat frame...');
          await GroupApiClient.instance.sendFrame(
            groupId: documentState.id,
            frame: frame,
          );

          logger?.writeLog('Send chat frame operation finished');
        },
      );
    } on QueueCancelledException {
      logger?.writeLog(
        'Send queue cancelled, chat frame not sent',
        level: LogLevel.debug,
      );
    }
  }

  Future<void> sendUpdateGroupName({required String name}) async {
    if (_state == SyncModelStateMode.local) {
      throw SyncModelSendError('Cannot update user name in local mode');
    }

    try {
      await _write(
        operation: () async {
          logger?.writeLog('Started update group name operation');
          final frame = await groupContext.changeGroup(name: name);

          await _saveGroupContext();

          logger?.writeLog('Sending change group frame...');
          await GroupApiClient.instance.sendFrame(
            groupId: documentState.id,
            frame: frame,
          );
          logger?.writeLog('Finished update group name operation');
        },
      );
    } on QueueCancelledException {
      logger?.writeLog(
        'Send queue cancelled, update group name frame not sent',
        level: LogLevel.debug,
      );
    }
  }

  Future<void> sendUpdateUserName({required String name}) async {
    if (_state == SyncModelStateMode.local) {
      throw SyncModelSendError('Cannot update user name in local mode');
    }

    try {
      return await _write(
        maxAttempts: 1,
        operation: () async {
          logger?.writeLog('Start change user name operation');
          final frame = await groupContext.changeUser(name: name);

          await _saveGroupContext();

          logger?.writeLog('Sending change user frame...');
          await GroupApiClient.instance.sendFrame(
            groupId: documentState.id,
            frame: frame,
          );
          logger?.writeLog('Change user frame was sent');
        },
      );
    } on QueueCancelledException {
      logger?.writeLog(
        'Send queue cancelled, change user frame not sent',
        level: LogLevel.debug,
      );
    }
  }

  Future<String> sendIdentifiedInvite({required Contact contact}) async {
    if (_state == SyncModelStateMode.local) {
      throw SyncModelSendError('Cannot create invite in local mode');
    }

    try {
      return await _write(
        operation: () async {
          logger?.writeLog('Create indentifiend invite operation started');
          final firstSpk = contact.spks.firstOrNull;
          final spkPublicKey = firstSpk != null
              ? Uint8List.fromList(firstSpk)
              : null;

          logger?.writeLog('Spk to use: $spkPublicKey', level: LogLevel.debug);

          final payload = Payload(
            crdt: CRDTPayload(fullDocument: documentState.crdt.save()),
          );

          logger?.writeLog('Creating identified invite frame');
          final (frame, invite) = await groupContext.addIdentifiedMember(
            identityPublicKey: contact.account.rawPublicKey,
            spkPublicKey: spkPublicKey,
            content: Payloads(payloads: [payload]).writeToBuffer(),
          );

          await _saveGroupContext();

          logger?.writeLog('Sending identified invite frame');
          await GroupApiClient.instance.sendFrame(
            groupId: documentState.id,
            frame: frame,
          );
          logger?.writeLog('Identified invite frame sent');

          final inviteLink = DeeplinkManager.instance.buildInvite(invite);

          if (spkPublicKey != null) {
            logger?.writeLog(
              'Removing spk contact spk..',
              level: LogLevel.debug,
            );
            await ContactsManager.instance.removeSpk(
              contact.account.actorId,
              spkPublicKey.toList(),
            );
          }

          return inviteLink;
        },
      );
    } on QueueCancelledException {
      logger?.writeLog(
        'Send queue cancelled, identified invite not sent',
        level: LogLevel.debug,
      );
      return "";
    }
  }

  Future<String> sendUnidentifiedInvite() async {
    if (_state == SyncModelStateMode.local) {
      throw SyncModelSendError('Cannot create invite in local mode');
    }

    try {
      return await _write(
        operation: () async {
          logger?.writeLog(
            'Started create unidentified member invite operation',
          );
          final secretKey = SecretManager.intance.generateSecretKey();

          final payloads = Payloads(
            payloads: [
              Payload(
                crdt: CRDTPayload(fullDocument: documentState.crdt.save()),
              ),
            ],
          ).writeToBuffer();

          logger?.writeLog('Creating unidentified invite frame..');
          final (frame, invite) = await groupContext.addUnidentifiedMember(
            secretKey: secretKey,
            content: payloads,
          );

          await _saveGroupContext();

          logger?.writeLog('Sending unidentified invite frame...');
          await GroupApiClient.instance.sendFrame(
            groupId: documentState.id,
            frame: frame,
          );
          logger?.writeLog('Create unidentified invite operation finished');

          return DeeplinkManager.instance.buildInvite(invite);
        },
      );
    } on QueueCancelledException {
      logger?.writeLog(
        'Send queue cancelled, unidentified invite not sent',
        level: LogLevel.debug,
      );
      return "";
    }
  }

  Future<void> sendRemoveMember({required String actorId}) async {
    if (_state == SyncModelStateMode.local) {
      throw SyncModelSendError('Cannot remove member in local mode');
    }

    try {
      await _write(
        operation: () async {
          logger?.writeLog('Remove member operation started');
          final frame = await groupContext.removeMember(
            userId: actorId,
            content: [],
          );

          await _saveGroupContext();

          logger?.writeLog('Sending remove member frame...');
          await GroupApiClient.instance.sendFrame(
            groupId: documentState.id,
            frame: frame,
          );
          logger?.writeLog('Remove member operation finished');
        },
      );
    } on QueueCancelledException {
      logger?.writeLog(
        'Send queue cancelled, remove member frame not sent',
        level: LogLevel.debug,
      );
    }
  }

  Future<void> sendJoinGroupFrame(Account user) async {
    try {
      await _write(
        operation: () async {
          logger?.writeLog('Join group operation started');
          final frame = await groupContext.joinGroupAs(
            user: BUser(name: user.name, publicKey: user.keypair.rawPublicKey),
          );

          await _saveGroupContext();

          logger?.writeLog('Sending join group frame...');
          await GroupApiClient.instance.sendFrame(
            groupId: documentState.id,
            frame: frame,
          );
          logger?.writeLog('Join group operation finished');
        },
      );
    } on QueueCancelledException {
      logger?.writeLog(
        'Send queue cancelled, join group frame not sent',
        level: LogLevel.debug,
      );
    }
  }

  Future<T> _write<T>({
    int maxAttempts = 3,
    required Future<T> Function() operation,
  }) async {
    return await _writeQueue.add(() async {
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          if (_processQueue.remainingItemCount > 0) {
            await _processQueue.onComplete;
          }

          return await operation();
        } catch (e) {
          if (attempt == maxAttempts) {
            rethrow;
          } else {
            logger?.writeLog(
              'Failed to perform send operation, attempt: $attempt, max attempts: $maxAttempts, retrying..: $e',
              level: LogLevel.warning,
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
    logger?.stateLog('Marking document as corrupted..');

    _emitCorruptedEvent();
    await clearState(
      disableNetworkListener: true,
      disableStateBroadcast: false,
      cancelPendingTasks: true,
    );

    logger?.stateLog('Document marked as corrupted');
  }

  Future<void> applyCrdtListOperation(List<ExposedCRDTPayload> payloads) async {
    logger?.modelLog('Applying crdt list..');

    _applyCrdtPayloadList(document: documentState, payloads: payloads);

    await _saveState();

    logger?.modelLog('Applied crdt list');
  }

  Future<void> makeLocal() async {
    await setState(SyncModelStateMode.local);
    await clearState();

    final oldId = documentState.id;
    final newId = UuidV4().generate();
    documentState.isLocal = true;
    documentState.id = newId;

    final oldBox = await Hive.openBox(oldId);
    final newBox = await Hive.openBox(newId);
    await newBox.putAll(oldBox.toMap());
    await oldBox.deleteFromDisk();

    await DB.instance.deleteDocumentState(oldId);
    await DB.instance.insertDocumentState(documentState: documentState);
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

  Future<void> _sendCrdtFrameList(List<Uint8List> data) async {
    final frame = await groupContext.createFrame(
      content: Payloads(
        payloads: data
            .map((e) => Payload(crdt: CRDTPayload(incrementalChange: e)))
            .toList(),
      ).writeToBuffer(),
    );

    await _saveGroupContext();

    await GroupApiClient.instance.sendFrame(
      groupId: documentState.id,
      frame: frame,
    );
  }
}

extension SyncModelHelpers on SyncModel {
  void _emitCorruptedEvent() {
    if (!_eventController.isClosed) {
      logger?.eventLog('Emit corrupted event');
      corrupted = true;
      _eventController.add(SyncModelCorruptedEvent());
    }
  }

  void _emitIsSyncingEvent(bool isSyncing) {
    if (!_eventController.isClosed) {
      logger?.eventLog('Emit is syncing event');
      this.isSyncing = isSyncing;
      _eventController.add(SyncModelSyncingEvent(isSyncing));
    }
  }

  void _emitRemovedFromGroupEvent() {
    if (!_eventController.isClosed) {
      logger?.eventLog('Emit removed from group event');
      _eventController.add(SyncModelRemovedFromGroupEvent());
    }
  }

  void _emitCrdtUpdatesEvent(BAutoCommit crdt) {
    if (!_eventController.isClosed) {
      logger?.eventLog('Emit crdt update event');
      _eventController.add(SyncModelCrdtEvent(crdt));
    }
  }

  void _emitGroupInfoUpdatesEvent(GroupInfo groupInfo) {
    if (!_eventController.isClosed) {
      logger?.eventLog('Group info changed, sending update..');
      _eventController.add(SyncModelGroupInfoEvent(groupInfo));
    }
  }

  void _applyCrdtPayloadList({
    required DocumentState document,
    required List<ExposedCRDTPayload> payloads,
    bool allowFullDocument = false,
  }) {
    logger?.modelLog('Number of CRDT payloads to apply: ${payloads.length}');
    logger?.modelLog(
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
          logger?.modelLog(
            'Received CRDT full document for ${document.id}',
            level: LogLevel.debug,
          );
          document.crdt = BAutoCommit.load(data: payload.crdt.fullDocument);
          break;
      }
    }

    if (payloads.isNotEmpty) {
      _emitCrdtUpdatesEvent(document.crdt);
    }

    logger?.modelLog(
      'Document state AFTER applying CRDT: ID ${document.id} ${document.crdt.getBlocks()}',
    );
  }

  Future<void> _saveGroupContext() async {
    if (saveToDb) {
      logger?.modelLog('Saving group context..');

      await _db.updateGroupContextDocumentState(
        id: documentState.id,
        parts: await groupContext.asParts(),
      );
    }
  }

  Future<void> _saveState() async {
    if (saveToDb) {
      logger?.modelLog('Saving document state..');
      await _db.updateDocumentState(
        documentState: documentState,
        groupContextParts: await groupContext.asParts(),
      );
    }
  }
}

extension SyncModelTest on SyncModel {
  Future<void> testSetup({bool allowFullDocument = false}) async {
    queuesProcessListener.listen();

    final hive = await Hive.openBox(documentState.id);
    final hiveChatController = HiveChatController(hive);
    chatManager = ChatManager(controller: hiveChatController);

    await setState(
      SyncModelStateMode.local,
      allowFullDocument: allowFullDocument,
    );
  }
}
