import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:rxdart/subjects.dart';
import 'package:zk_notion_app/api/centrifuge.dart';
import 'package:zk_notion_app/api/client.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/protos/zero_art.pb.dart';
import 'package:zk_notion_app/src/rust/api/group_context.dart';
import 'package:zk_notion_app/storage/account_storage.dart';
import 'package:zk_notion_app/storage/models.dart';
import 'package:zk_notion_app/storage/sqlite/db.dart';
import 'package:zk_notion_app/utils/group_context_factory.dart';

enum ProcessingStatus {
  doNotProcess,
  process,
  initalProcess,
  initialProcessFinished,
  editing,
}

class SyncProviderModel {
  final Document document;
  final BGroupContext groupContext;
  final String jwt;
  late final StreamSubscription<SSEModel> listener;
  ProcessingStatus status = ProcessingStatus.initalProcess;

  SyncProviderModel({
    required this.document,
    required this.groupContext,
    required this.jwt,
    required Stream<SSEModel> steam,
  }) {
    listener = listen(steam);
  }

  Future<void> initalProcess() async {
    final signature = groupContext.signWithTk(groupId: document.id, nonce: [0]);

    while (true) {
      final result = await GroupApiClient.instance.getFrames(
        epoch: groupContext.getEpoch().toInt(),
        groupId: document.id,
        signature: base64UrlEncode(signature),
        nonce: base64UrlEncode([0]),
        messageSequenceNumber: document.sequenceNumber,
      );

      if (result.spFrames.first.seqNum.toInt() == document.sequenceNumber) {
        break;
      }

      for (final spFrame in result.spFrames.reversed) {
        final rawFramePayloads = groupContext.processFrame(
          spFrame: spFrame.writeToBuffer(),
        );

        // If rawFramePayloads is empty,
        // it indicates that the frame belongs to the current user,
        // thus processing is unnecessary.

        for (final rawPayload in rawFramePayloads) {
          final payload = Payload.fromBuffer(rawPayload);

          switch (payload.whichContent()) {
            case Payload_Content.crdt:
              _handleCRDT(payload.crdt);
            case Payload_Content.action:
              _handleGroupOperations(payload.action);
            default:
              logger.i('Received unknown payload type');
              throw UnimplementedError('Received unknown payload type');
          }
        }
      }
      document.sequenceNumber = result.spFrames.first.seqNum.toInt();
    }

    await DB.instance.updateDocument(
      doc: document,
      parts: groupContext.asParts(),
    );

    status = ProcessingStatus.initialProcessFinished;
  }

  void _handleCRDT(CRDTPayload crdt) {
    switch (crdt.whichPayload()) {
      case CRDTPayload_Payload.incrementalChange:
        logger.d('Received incremental change');
        document.automergeDoc.loadIncremental(bytes: crdt.incrementalChange);
        document.automergeDoc.emptyChange();
      case CRDTPayload_Payload.fullDocument:
        logger.d('Received full document');
        document.automergeDoc.loadIncremental(bytes: crdt.incrementalChange);
        document.automergeDoc.emptyChange();
      case CRDTPayload_Payload.mediaAttachment:
        throw UnimplementedError('Media attachments not supported');
      case CRDTPayload_Payload.notSet:
        throw UnimplementedError('CRDT payload not set');
    }
  }

  void _handleGroupOperations(GroupActionPayload gop) {
    switch (gop.whichAction()) {
      case GroupActionPayload_Action.init:
        logger.d('init received');
      case GroupActionPayload_Action.inviteMember:
        logger.d('invite member received');
      case GroupActionPayload_Action.removeMember:
        throw UnimplementedError('Remove member not supported');
      case GroupActionPayload_Action.joinGroup:
        logger.d('join group received');
      case GroupActionPayload_Action.changeUser:
        throw UnimplementedError('Change user not supported');
      case GroupActionPayload_Action.changeGroup:
        throw UnimplementedError('Change group not supported');
      case GroupActionPayload_Action.leaveGroup:
        throw UnimplementedError('Leave group not supported');
      case GroupActionPayload_Action.finalizeRemoval:
        throw UnimplementedError('Finalize removal not supported');
      case GroupActionPayload_Action.notSet:
        throw UnimplementedError('group operation not set');
    }
  }

  StreamSubscription<SSEModel> listen(Stream<SSEModel> stream) {
    return stream.listen(
      (event) {
        if (event.event == '') return;
        logger.i(
          'Centrifugo event id: ${event.id}, event: ${event.event}, data: ${event.data}',
        );
      },
      onError: (error, [stackTrace]) {
        logger.e('Centrifugo error: $error, trace: $stackTrace');
      },
      onDone: () {
        logger.i('Centrifugo done');
      },
      cancelOnError: false,
    );
  }

  Future<void> dispose() async {
    logger.i('Sync provider disposed');
    await listener.cancel();
  }
}

class SyncProvider {
  final _centrifugo = CentrifugeProvider.instance;
  final _db = DB.instance;
  final _api = GroupApiClient.instance;
  final _accountStorage = AccountStorage.instance;

  Account? _acc;
  Account get _account => _acc!;

  List<SyncProviderModel> get current => subject.value;
  BehaviorSubject<List<SyncProviderModel>> subject = BehaviorSubject.seeded([]);

  static final instance = SyncProvider();

  Future<void> init() async {
    final documents = await _db.getDocumentList();
    _acc = await _accountStorage.getAccount();

    if (_acc == null) {
      throw Exception('No account, unreachable flow');
    }

    for (final doc in documents) {
      final groupContext = doc.groupContextParts.toGroupContext(
        identitySecretKey: Uint8List.fromList(_account.keypair.rawPrivateKey),
      );

      add(doc, groupContext);
    }
  }

  Future<SyncProviderModel> add(
    Document document,
    BGroupContext groupContext,
  ) async {
    return await _db.transaction((db) async {
      await db.insertDocument(document: document);
      final syncModel = await _setupSync(document, groupContext);

      subject.value.add(syncModel);
      return syncModel;
    });
  }

  Future<void> remove(String chatId) async {
    await _db.transaction((db) async {
      final syncModel = subject.value
          .where((element) => element.document.id == chatId)
          .firstOrNull;

      if (syncModel == null) return;

      await syncModel.dispose();
      await _db.deleteDocument(syncModel.document.id);

      subject.value.removeWhere((element) => element.document.id == chatId);
    });
  }

  SyncProviderModel get(String chatId) {
    return current.firstWhere((element) => element.document.id == chatId);
  }

  List<SyncProviderModel> getAll() {
    return current;
  }

  Future<SyncProviderModel> _setupSync(
    Document doc,
    BGroupContext groupContext,
  ) async {
    final challenge = await _api.getChallenge(doc.id);

    final jwt = await _api.getCentrifugoJWT(
      groupId: doc.id,
      epoch: groupContext.getEpoch().toInt(),
      proof: base64Encode(
        groupContext.signChallenge(challenge: base64Decode(challenge)),
      ),
      challenge: challenge,
    );

    final stream = await _centrifugo.connect(jwt);

    final syncModel = SyncProviderModel(
      document: doc,
      groupContext: groupContext,
      jwt: jwt,
      steam: stream,
    );

    syncModel.initalProcess();
    return syncModel;
  }
}
