import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:zk_notion_app/api/client.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/protos/zero_art.pb.dart';
import 'package:zk_notion_app/screens/doc_members.dart';
import 'package:zk_notion_app/screens/editor/overrides/helpers.dart';
import 'package:zk_notion_app/screens/history_page.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:zk_notion_app/src/rust/api/group_context.dart';
import 'package:zk_notion_app/storage/account_storage.dart';
import 'package:zk_notion_app/storage/models.dart' as models;
import 'package:zk_notion_app/storage/sqlite/db.dart';
import 'package:zk_notion_app/utils/editor_automerge.dart';
import 'package:zk_notion_app/utils/group_context_factory.dart';

class EditorPageVm extends ChangeNotifier {
  final String docId;
  final _accStorage = AccountStorage();
  final composer = MutableDocumentComposer();

  late Editor editor;

  models.Document? doc;
  BGroupContext? groupContext;
  Timer? _saveTicker;
  Timer? _listenFramesTicker;
  bool isProcessingFrames = false;

  EditorPageVm(this.docId) {
    editor = createDefaultDocumentEditorOverriden(
      document: MutableDocument.empty(),
      composer: composer,
    );
  }

  Future<void> init() async {
    doc = await DB.instance.getDocumentById(docId);

    final account = await _accStorage.getAccount();
    if (account == null) {
      throw Exception('To open a document, you must have an account');
    }

    if (doc == null) {
      throw Exception('Document not found');
    }

    final safeDoc = doc!;

    groupContext = doc!.groupContextParts.toGroupContext(
      identitySecretKey: Uint8List.fromList(account.keypair.rawPrivateKey),
    );

    doc!.automergeDoc.setActorId(uuid: account.actorId);
    doc!.automergeDoc.setupBlockLabel();

    if (doc!.automergeDoc.getBlocks().isNotEmpty) {
      editor = createDefaultDocumentEditorOverriden(
        document: EditorAutomergeUtils.instance.toDoc(safeDoc.automergeDoc),
        composer: composer,
      );
    }

    _saveTicker = Timer.periodic(const Duration(seconds: 3), (_) => _commit());
    _listenFramesTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      try {
        listenFrames();
      } catch (e) {
        logger.e(e);
      }
    });
    notifyListeners();
  }

  Future<void> _commit() async {
    if (groupContext == null) {
      throw Exception('Group context is null');
    }

    if (doc == null) {
      throw Exception('Document is null');
    }

    EditorAutomergeUtils.instance.fromDoc(editor.document, doc!.automergeDoc);

    final incrementalChange = doc!.automergeDoc.saveIncremental();
    if (incrementalChange.isEmpty) return;

    /// TODO: On page launch sends empty incremental change

    final payload = Payload(
      crdt: CRDTPayload(incrementalChange: incrementalChange),
    ).writeToBuffer();

    final frame = groupContext!.createFrame(payloads: [payload]);
    await GroupApiClient.instance.sendFrame(groupId: doc!.id, frame: frame);

    doc!.automergeDoc.commit();
  }

  Future<void> listenFrames() async {
    if (groupContext == null) {
      throw Exception('Group context is null');
    }

    if (doc == null) {
      throw Exception('Document is null');
    }

    if (isProcessingFrames) {
      logger.i('Skipping processing frames, already processing');
      return;
    }

    isProcessingFrames = true;
    logger.d('Started processing frames...');

    try {
      final sequenceNumber = await processFrames(doc!, groupContext!);

      if (sequenceNumber != null) {
        doc!.sequenceNumber = sequenceNumber;
        logger.i(
          'Frames processed successfully, new sequenceNumber=$sequenceNumber',
        );
      } else {
        logger.w('No sequenceNumber returned from processFrames');
      }
    } catch (e, st) {
      logger.e('Error while processing frames', error: e, stackTrace: st);
      rethrow;
    } finally {
      isProcessingFrames = false;
      logger.d('Finished processing frames');
    }
  }

  /// Returns last processed frame sequence number
  Future<int?> processFrames(
    models.Document doc,
    BGroupContext groupContext,
  ) async {
    final signatureTk = groupContext.signWithTk(groupId: doc.id, nonce: [0]);

    final result = await GroupApiClient.instance.getFrames(
      groupId: doc.id,
      signature: base64UrlEncode(signatureTk),
      nonce: base64UrlEncode([0]),
      messageSequenceNumber: doc.sequenceNumber,
      epoch: groupContext.getEpoch().toInt(),
    );

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
            logger.i('Received CRDT payload');
            _handleCRDT(payload.crdt, doc);
          case Payload_Content.action:
            logger.i('Received action payload');
            _handleGroupOperations(payload.action, doc);
          default:
            logger.i('Received unknown payload type');
            throw UnimplementedError('Received unknown payload type');
        }
      }
    }

    return result.spFrames.firstOrNull?.seqNum.toInt();
  }

  void _handleCRDT(CRDTPayload crdt, models.Document doc) {
    switch (crdt.whichPayload()) {
      case CRDTPayload_Payload.incrementalChange:
        logger.d('Received incremental change');
        doc.automergeDoc.loadIncremental(bytes: crdt.incrementalChange);
        createDefaultDocumentEditorOverriden(
          document: EditorAutomergeUtils.instance.toDoc(doc.automergeDoc),
          composer: composer,
        );
      case CRDTPayload_Payload.fullDocument:
        logger.d('Received full document');
        doc.automergeDoc.loadIncremental(bytes: crdt.incrementalChange);
        createDefaultDocumentEditorOverriden(
          document: EditorAutomergeUtils.instance.toDoc(doc.automergeDoc),
          composer: composer,
        );
      case CRDTPayload_Payload.mediaAttachment:
        throw UnimplementedError('Media attachments not supported');
      case CRDTPayload_Payload.notSet:
        throw UnimplementedError('CRDT payload not set');
    }

    notifyListeners();
  }

  void _handleGroupOperations(GroupActionPayload gop, models.Document doc) {
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

  Future<List<MemberScreenModel>> prepareMembers() async {
    final account = await _accStorage.getAccount();
    return doc!.members
        .map(
          (e) => MemberScreenModel(
            member: e,
            isYou: e.account.actorId == account?.actorId,
          ),
        )
        .toList();
  }

  List<ChangeEvent> prepareChanges() {
    return doc!.automergeDoc
        .getChangeList()
        .indexed
        .map(
          (e) => ChangeEvent(
            title: 'Change',
            actorIdHex: e.$2.actorIdHex(),
            changeHashHex: e.$2.changeHash(),
            date: e.$2.timestamp(),
            isInitial: e.$1 == 0,
          ),
        )
        .toList()
        .reversed
        .toList();
  }

  @override
  void dispose() {
    _saveTicker?.cancel();
    _listenFramesTicker?.cancel();
    _commit();
    DB.instance.updateDocument(doc: doc!, parts: groupContext!.toParts());
    super.dispose();
  }
}
