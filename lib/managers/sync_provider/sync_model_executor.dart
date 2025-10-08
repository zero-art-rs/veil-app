import 'package:veil/api/group_api_client.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/screens/editor/frame_processor/executor.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/editor_automerge.dart';
import 'package:veil/utils/group_context_factory.dart';
import 'package:veil/utils/payload.dart';

/// Plays role of mutex for [SyncModel]
class SyncModelExecutor {
  final SyncProviderModel syncModel;
  final _executor = PriorityExecutorQueue();

  final _db = DB.instance;

  SyncModelExecutor(this.syncModel);

  Future<String> appyCrdtOperation(
    List<ExposedCRDTPayload> payloads, {
    TaskPriority priority = TaskPriority.high,
  }) async {
    return await _executor.add(() async {
      _syncDocumentWithPayload(syncModel.document.automergeDoc, payloads);

      await _db.updateDocument(
        doc: syncModel.document,
        parts: syncModel.groupContext.asParts(),
      );

      return EditorAutomergeUtils.instance.toText(
        syncModel.document.automergeDoc,
      );
    });
  }

  Future<void> makeLocalOperation() async {
    await _executor.add(() async {
      await syncModel.listener?.cancel();
      syncModel.document.localOnly = true;
    });
  }

  Future<(List<ExposedCRDTPayload> payloads, bool fromCurrentUser)>
  processFrame(SPFrame spframe) async {
    return await _executor.add(() async {
      List<ExposedCRDTPayload> exposedCrdtPayload = [];

      final rawPayloads = syncModel.groupContext.processFrame(
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

      syncModel.document.sequenceNumber = spframe.seqNum.toInt();

      await _db.updateDocument(
        doc: syncModel.document,
        parts: syncModel.groupContext.asParts(),
      );
      return (exposedCrdtPayload, false);
    });
  }

  Future<void> sendFrame(String md, List<ExposedCRDTPayload> buffer) async {
    await _executor.add(() async {
      final forkedDocument = syncModel.document.automergeDoc.fork();

      EditorAutomergeUtils.instance.toDoc(md, forkedDocument);
      forkedDocument.commit();

      _syncDocumentWithPayload(forkedDocument, buffer);

      final saveIncremential = forkedDocument.saveIncremental();

      await GroupApiClient.instance.sendFrame(
        groupId: syncModel.document.id,
        frame: syncModel.groupContext.createFrame(
          payloads: [
            Payload(
              crdt: CRDTPayload(incrementalChange: saveIncremential),
            ).writeToBuffer(),
          ],
        ),
      );

      syncModel.document.automergeDoc.loadIncremental(bytes: saveIncremential);
      syncModel.groupContext.commitState();

      await _db.updateDocument(
        doc: syncModel.document,
        parts: syncModel.groupContext.asParts(),
      );
    });
  }

  Future<T> operate<T>(
    T Function(SyncProviderModel syncModel) callback, {
    TaskPriority priority = TaskPriority.high,
  }) async {
    return await _executor.add(
      () async => callback(syncModel),
      priority: priority,
    );
  }
}

void _syncDocumentWithPayload(
  BAutoCommit document,
  List<ExposedCRDTPayload> payloads,
) {
  for (final payload in payloads) {
    switch (payload.kind) {
      case ExposedCRDTPayloadKind.incrementalChange:
        final incrementalChange = payload.crdt.incrementalChange;
        document.loadIncremental(bytes: incrementalChange);
      default:
    }
  }
}
