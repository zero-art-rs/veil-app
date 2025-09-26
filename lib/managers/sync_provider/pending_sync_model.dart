import 'dart:async';
import 'dart:convert';

import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:zk_notion_app/api/client.dart';
import 'package:zk_notion_app/managers/sync_provider/sync_model.dart';
import 'package:zk_notion_app/protos/zero_art.pb.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:zk_notion_app/src/rust/api/group_context.dart';
import 'package:zk_notion_app/storage/models.dart';
import 'package:zk_notion_app/utils/payload.dart';

import '../../main.dart';

class SyncPendingProviderModel {
  final Document document;
  final BPendingGroupContext groupContext;
  final String jwt;
  late final StreamSubscription<SSEModel> listener;
  final List<SPFrame> buffer = [];

  SyncPendingProviderModel({
    required this.document,
    required this.groupContext,
    required this.jwt,
  });

  /// Listen, transform data to frames send to processor.
  void listenCentrifugo(Stream<SSEModel> stream) {
    listener = stream.listen(
      (event) {
        if (event.data == null || event.data!.isEmpty) return;
        final rawJson = json.decode(event.data!);
        if (rawJson['pub'] == null) return;
        final frameBytes = base64Decode(rawJson['pub']['data'].toString());
        final frame = SPFrame.fromBuffer(frameBytes);
        buffer.add(frame);
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

  Future<BGroupContext> synchronizeInitially(BUser user) async {
    logger.i('document.sequenceNumber ${document.sequenceNumber}');
    logger.i('group epoch ${groupContext.getEpoch().toInt()}');

    while (true) {
      // TODO: Make better handling
      try {
        await poll();
      } catch (err) {
        logger.e('Pending sync provider poll error $err');
        rethrow;
      }

      // Load buffered frames from centrifugo
      for (final frame in buffer) {
        processFrame(frame);
      }

      logger.i('User to join  ${user.id()}');
      final frame = groupContext.joinGroupAs(user: user);
      try {
        await GroupApiClient.instance.sendFrame(
          groupId: document.id,
          frame: frame,
        );
        logger.i('Send join group frame');
        await listener.cancel();
        return groupContext.upgrade();
      } catch (err) {
        logger.e('Pending sync provider sendFrame error, repolling..: $err');
      }
    }
  }

  Future<void> poll() async {
    bool hasMore = true;

    while (hasMore) {
      final signature = groupContext.signWithTk(
        groupId: document.id,
        nonce: [0],
      );

      final result = await GroupApiClient.instance.getFrames(
        epoch: groupContext.getEpoch().toInt(),
        groupId: document.id,
        signature: base64UrlEncode(signature),
        nonce: base64UrlEncode([0]),
        messageSequenceNumber: document.sequenceNumber,
      );

      for (final spFrame in result.spFrames.reversed) {
        processFrame(spFrame);
      }

      final newSeqNum = result.spFrames.first.seqNum.toInt();
      if (newSeqNum == document.sequenceNumber) {
        hasMore = false;
      } else {
        document.sequenceNumber = newSeqNum;
      }
    }
  }

  void processFrame(SPFrame spFrame) {
    final rawFramePayloads = groupContext.processFrame(
      frame: spFrame.frame.writeToBuffer(),
    );

    // NOTE:
    // If rawFramePayloads is empty,
    // it indicates that the frame belongs to the current user,
    // thus processing is unnecessary.
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
}
