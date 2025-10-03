import 'dart:async';
import 'dart:convert';

import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/managers/change_manager.dart';
import 'package:veil/managers/sync_provider/pending_sync_model.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/utils/payload.dart';

import '../../main.dart';

class SyncProviderModel {
  final Document document;
  final BGroupContext groupContext;
  final String jwt;
  final StreamSubscription<SSEModel> listener;

  SyncProviderModel({
    required this.document,
    required this.groupContext,
    required this.jwt,
    required this.listener,
  });

  factory SyncProviderModel.fromPending(
    SyncPendingProviderModel model,
    BGroupContext groupContext,
  ) {
    return SyncProviderModel(
      document: model.document,
      groupContext: groupContext,
      jwt: model.jwt,
      listener: model.listener,
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

  Future<void> synchronizeInitially() async {
    logger.i('initial document.sequenceNumber ${document.sequenceNumber}');
    logger.i('initial group epoch ${groupContext.getEpoch().toInt()}');

    while (true) {
      final signature = groupContext.signWithTk(
        groupId: document.id,
        nonce: [0],
      );

      try {
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
            frame: spFrame.frame.writeToBuffer(),
          );

          for (final rawPayload in rawFramePayloads) {
            final payload = Payload.fromBuffer(rawPayload);

            final (crdt, _) = PayloadUtils.instance.exposePayload(payload);

            if (crdt == null) continue;

            switch (crdt.kind) {
              case ExposedCRDTPayloadKind.incrementalChange:
                logger.d('Received incremental change');
                document.automergeDoc.loadIncremental(
                  bytes: crdt.crdt.incrementalChange,
                );
              case ExposedCRDTPayloadKind.fullDocument:
                logger.d('Received full document');
                document.automergeDoc = BAutoCommit.load(
                  data: crdt.crdt.fullDocument,
                );
            }
          }
        }

        document.sequenceNumber = result.spFrames.first.seqNum.toInt();
      } catch (err) {
        logger.e('Sync provider inital process error: $err');
      }
    }
  }

  Future<void> dispose() async {
    logger.i('Sync provider disposed');
    await listener.cancel();
  }
}
