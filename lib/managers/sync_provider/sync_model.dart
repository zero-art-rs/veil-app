import 'dart:async';
import 'dart:convert';

import 'package:async_queue/async_queue.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/managers/contacts_manager.dart';
import 'package:veil/managers/sharing/deeplink_manager.dart';
import 'package:veil/managers/sync_provider/sync_buffer.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
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
  StreamSubscription<SSEModel>? listener;
  final _db = DB.instance;

  final _crdtBuffer = LockedBuffer<ExposedCRDTPayload>();
  final _processQueue = AsyncQueue();
  final _sendQueue = AsyncQueue();

  bool bufferFrames = true;

  final _crdtUpdatesEvent = StreamController<BAutoCommit>.broadcast();
  final _removedFromGroupEvent = StreamController<bool>.broadcast();
  final _isProcessing = StreamController<bool>.broadcast();

  Stream<BAutoCommit> get crdtUpdatesEvent => _crdtUpdatesEvent.stream;
  Stream<bool> get removedFromGroupEvent => _removedFromGroupEvent.stream;
  Stream<bool> get isProcessing => _isProcessing.stream;

  get isLocal => document.localOnly;

  SyncModel({
    required this.document,
    required this.groupContext,
    required this.listener,
  });

  bool isUserInGroup() {
    return groupContext.retrieveGroupInfo().members.any(
      (e) => e.id == AccountSecureStorage.instance.account.actorId,
    );
  }
}

extension SyncModelInit on SyncModel {
  void listenProcess() {
    _processQueue.addQueueListener((e) {
      _isProcessing.add(e.currentQueueSize != 0 && _sendQueue.size != 0);
    });

    _sendQueue.addQueueListener((e) {
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
        try {
          final rawFramePayloads = await groupContext.processFrame(
            frame: spFrame.frame.writeToBuffer(),
          );

          for (final rawPayload in rawFramePayloads) {
            final payload = Payload.fromBuffer(rawPayload);

            final (crdt, _) = PayloadUtils.instance.exposePayload(payload);

            if (crdt == null) continue;

            switch (crdt.kind) {
              case ExposedCRDTPayloadKind.incrementalChange:
                document.automergeDoc.loadIncremental(
                  bytes: crdt.crdt.incrementalChange,
                );
              case ExposedCRDTPayloadKind.fullDocument:
                logger.d('Received crdt full document');
                document.automergeDoc = BAutoCommit.load(
                  data: crdt.crdt.fullDocument,
                );
            }
          }
        } catch (e) {
          if (e.toString().contains('Changes already applied or merged')) {
            continue;
          } else {
            rethrow;
          }
        }
      }

      document.sequenceNumber = result.spFrames.first.seqNum.toInt();
    }

    await _db.updateDocument(
      doc: document,
      parts: await groupContext.asParts(),
    );

    logger.d(
      'Document sequence number after polling: ${document.sequenceNumber}',
    );
    logger.d(
      'Document epoch after polling: ${(await groupContext.epoch()).toInt()}',
    );
  }

  Future<void> dispose() async {
    logger.i('Sync provider disposed');
    await listener?.cancel();
  }
}

extension SyncModelHandle on SyncModel {
  void bufferizeFrames() {
    return _processQueue.addJob(() async {
      logger.i('Change process frames to buffer mode');
      bufferFrames = true;
    });
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
  }
}

extension SyncModelProcessOperations on SyncModel {
  void processFrame(SPFrame spframe) async {
    _processQueue.addJob(() async {
      logger.i('Received frame, processing..');
      logger.d('Received frame, frame epoch: ${spframe.frame.frame.epoch}..');
      logger.d('Received frame, frame seqNum: ${spframe.seqNum}..');

      try {
        final (crdtList, _) = await _processFrame(spframe);

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
      } catch (e) {
        if (e.toString().contains('User removed from group')) {
          logger.i('User removed from group, making local only');
          _removedFromGroupEvent.add(true);
          await disableNetworkSyncOperation();
          await LocalStateUtils.instance.makeDocumentLocal(document);
        } else {
          rethrow;
        }
      }
    });

    _processQueue.start();
  }
}

extension SyncModelSendOperations on SyncModel {
  Future<void> sendCrdtFrame(String md) async {
    _sendQueue.addJob(() async {
      logger.i('Sending crdt frame..');
      final snapshot = await _crdtBuffer.snapshot();
      logger.d('Snapshot size: ${snapshot.length}');
      await _sendCrdtFrame(md, snapshot);
      await _crdtBuffer.removeWhere((e) => snapshot.contains(e));
      logger.d('Buffer size after removal: ${await _crdtBuffer.length()}');
      _crdtUpdatesEvent.add(document.automergeDoc);
      logger.i('Sent crdt frame');
    }, retryTime: 3);

    await _sendQueue.start();
  }

  Future<String> createInviteLink({Contact? contact}) async {
    final inviteLinkStream = StreamController<String>();

    _sendQueue.addJob(() async {
      final secretKey = SecretManager.intance.generateSecretKey();

      final payload = Payload(
        crdt: CRDTPayload(fullDocument: document.automergeDoc.save()),
      ).writeToBuffer();

      logger.i('Creating unidentified member invite...');
      final (frame, invite) = await groupContext.addUnidentifiedMember(
        secretKey: secretKey,
        payloads: [payload],
      );

      logger.i('Sending unidentified member invite frame...');
      await GroupApiClient.instance.sendFrame(
        groupId: document.id,
        frame: frame,
      );

      final inviteLink = DeeplinkManager.instance.buildInvite(invite);

      await DB.instance.updateDocument(
        doc: document,
        parts: await groupContext.asParts(),
      );

      inviteLinkStream.add(inviteLink);
    }, retryTime: -1);

    await _sendQueue.start();

    return inviteLinkStream.stream.first;
  }

  Future<void> removeMember({required String actorId}) async {
    final executedHandle = StreamController<bool>();

    _sendQueue.addJob(() async {
      logger.i('Removing member in group context..');
      final frame = await groupContext.removeMember(
        userId: actorId,
        payloads: [],
      );

      logger.i('Sending remove member frame...');
      await GroupApiClient.instance.sendFrame(
        groupId: document.id,
        frame: frame,
      );

      logger.i('Member removed from document');
      await DB.instance.updateDocument(
        doc: document,
        parts: await groupContext.asParts(),
      );

      executedHandle.add(true);
    });

    await _sendQueue.start();
    await executedHandle.stream.first;
  }

  Future<void> sendJoinGroupFrame(Account user) async {
    _sendQueue.addJob(() async {
      await _sendJoinGroupFrame(user);
    }, retryTime: 3);

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

    await _db.updateDocument(
      doc: document,
      parts: await groupContext.asParts(),
    );
  }

  Future<(List<ExposedCRDTPayload> payloads, bool fromCurrentUser)>
  _processFrame(SPFrame spframe) async {
    List<ExposedCRDTPayload> exposedCrdtPayload = [];
    final rawPayloads = await groupContext.processFrame(
      frame: spframe.frame.writeToBuffer(),
    );

    if (rawPayloads.isEmpty) {
      return (exposedCrdtPayload, true);
    }

    for (final rawPayload in rawPayloads) {
      final payload = Payload.fromBuffer(rawPayload);

      final (crdt, _) = PayloadUtils.instance.exposePayload(payload);
      if (crdt == null) continue;

      exposedCrdtPayload.add(crdt);
    }

    document.sequenceNumber = spframe.seqNum.toInt();

    await _db.updateDocument(
      doc: document,
      parts: await groupContext.asParts(),
    );
    return (exposedCrdtPayload, false);
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
        payloads: [
          Payload(
            crdt: CRDTPayload(incrementalChange: saveIncremential),
          ).writeToBuffer(),
        ],
      ),
    );

    document.automergeDoc.loadIncremental(bytes: saveIncremential);

    await _db.updateDocument(
      doc: document,
      parts: await groupContext.asParts(),
    );
  }

  Future<void> _sendJoinGroupFrame(Account user) async {
    logger.i('Sending join group frame..');
    final frame = await groupContext.joinGroupAs(
      user: BUser(name: user.name, publicKey: user.keypair.rawPublicKey),
    );

    await GroupApiClient.instance.sendFrame(groupId: document.id, frame: frame);
    logger.i('Sent join group frame');

    await _db.updateDocument(
      doc: document,
      parts: await groupContext.asParts(),
    );
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
