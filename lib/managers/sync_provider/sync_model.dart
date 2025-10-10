import 'dart:async';
import 'dart:convert';

import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/managers/change_manager.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/editor_automerge.dart';
import 'package:veil/utils/group_context_factory.dart';
import 'package:veil/utils/payload.dart';

import '../../main.dart';

class SyncProviderModel {
  final Document document;
  final BGroupContext groupContext;
  final String jwt;
  final StreamSubscription<SSEModel>? listener;
  final _db = DB.instance;

  get isLocal => document.localOnly;

  SyncProviderModel({
    required this.document,
    required this.groupContext,
    required this.jwt,
    required this.listener,
  });

  factory SyncProviderModel.local(
    Document document,
    BGroupContext groupContext,
  ) {
    return SyncProviderModel(
      document: document,
      groupContext: groupContext,
      jwt: "",
      listener: null,
    );
  }

  factory SyncProviderModel.withListener(
    Document document,
    BGroupContext groupContext,
    String jwt,
    Stream<SSEModel> stream,
  ) {
    final changeManager = ChangeManager.instance;

    final listener = stream.listen(
      (event) {
        if (event.data == null || event.data!.isEmpty) return;

        final rawJson = json.decode(event.data!);
        if (rawJson['pub'] == null) return;

        final frameBytes = base64Decode(rawJson['pub']['data'].toString());

        final frame = SPFrame.fromBuffer(frameBytes);

        changeManager.addFrame(
          groupId: document.id,
          frame: frame,
          sequenceNumber: frame.seqNum.toInt(),
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

    return SyncProviderModel(
      document: document,
      groupContext: groupContext,
      jwt: jwt,
      listener: listener,
    );
  }
}

extension SyncModelSync on SyncProviderModel {
  Future<void> synchronizeInitially({bool allowFullDocument = false}) async {
    logger.i('initial document.sequenceNumber ${document.sequenceNumber}');
    logger.i('initial group epoch ${(await groupContext.epoch()).toInt()}');

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
        final rawFramePayloads = await groupContext.processFrame(
          frame: spFrame.frame.writeToBuffer(),
        );

        for (final rawPayload in rawFramePayloads) {
          final payload = Payload.fromBuffer(rawPayload);

          final (crdt, _) = PayloadUtils.instance.exposePayload(payload);

          if (crdt == null) continue;

          _syncDocumentWithCrdt(document.automergeDoc, [
            crdt,
          ], withFullDoc: allowFullDocument);
        }
      }

      document.sequenceNumber = result.spFrames.first.seqNum.toInt();
    }
  }

  Future<void> dispose() async {
    logger.i('Sync provider disposed');
    await listener?.cancel();
  }
}

extension SyncModelOperations on SyncProviderModel {
  Future<String> appyCrdtListOperation(
    List<ExposedCRDTPayload> payloads,
  ) async {
    _syncDocumentWithCrdt(document.automergeDoc, payloads);

    await _db.updateDocument(
      doc: document,
      parts: await groupContext.asParts(),
    );

    return EditorAutomergeUtils.instance.toText(document.automergeDoc);
  }

  Future<void> disableNetworkSyncOperation() async {
    await listener?.cancel();
    document.localOnly = true;
  }

  Future<(List<ExposedCRDTPayload> payloads, bool fromCurrentUser)>
  processFrame(SPFrame spframe) async {
    List<ExposedCRDTPayload> exposedCrdtPayload = [];

    logger.i(
      'Processing frame, group context epoch: ${await groupContext.epoch()}',
    );
    logger.i('Processing frame, frame epoch: ${spframe.frame.frame.epoch}');

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

  Future<void> sendCrdtFrame(String md, List<ExposedCRDTPayload> buffer) async {
    final forkedDocument = document.automergeDoc.fork();
    forkedDocument.setActorId(
      uuid: AccountSecureStorage.instance.account.actorId,
    );
    EditorAutomergeUtils.instance.toDoc(md, forkedDocument);
    forkedDocument.commit();

    _syncDocumentWithCrdt(forkedDocument, buffer);

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

  Future<void> sendJoinGroupFrame(Account user) async {
    final frame = await groupContext.joinGroupAs(
      user: BUser(name: user.name, publicKey: user.keypair.rawPublicKey),
    );

    await GroupApiClient.instance.sendFrame(groupId: document.id, frame: frame);
  }
}

void _syncDocumentWithCrdt(
  BAutoCommit document,
  List<ExposedCRDTPayload> payloads, {
  bool withFullDoc = false,
}) {
  for (final payload in payloads) {
    switch (payload.kind) {
      case ExposedCRDTPayloadKind.incrementalChange:
        final incrementalChange = payload.crdt.incrementalChange;
        document.loadIncremental(bytes: incrementalChange);
      case ExposedCRDTPayloadKind.fullDocument:
        if (withFullDoc) {
          logger.d('Received full document');
          document = BAutoCommit.load(data: payload.crdt.fullDocument);
        }
    }
  }
}
