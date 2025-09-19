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

    groupContext = doc!.groupContextParts.toGroupContext(
      identitySecretKey: Uint8List.fromList(account.keypair.rawPrivateKey),
    );

    doc!.automergeDoc.setActorId(uuid: account.actorId);
    doc!.automergeDoc.setupBlockLabel();

    if (doc!.automergeDoc.getBlocks().isNotEmpty) {
      editor = createDefaultDocumentEditorOverriden(
        document: EditorAutomergeUtils.instance.toDoc(doc!.automergeDoc),
        composer: composer,
      );
    }

    // _saveTicker = Timer.periodic(const Duration(seconds: 3), (_) => commit());
    _listenFramesTicker = Timer.periodic(
      const Duration(seconds: 5),
      (_) => listenFrames(),
    );
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

    final crdt = CRDTPayload(fullDocument: incrementalChange);
    final payload = Payload(crdt: crdt).writeToBuffer();

    final frame = groupContext!.createFrame(payloads: [payload]);
    await GroupApiClient.instance.sendFrame(groupId: doc!.id, frame: frame);

    doc!.automergeDoc.commit();
  }

  Future<void> listenFrames() async {
    try {
      if (groupContext == null) {
        throw Exception('Group context is null');
      }

      if (doc == null) {
        throw Exception('Document is null');
      }

      final signatureTk = groupContext!.signWithTk(
        groupId: doc!.id,
        nonce: [0],
      );
      final groupContextEpoch = groupContext!.getEpoch();

      final result = await GroupApiClient.instance.getFrames(
        groupId: doc!.id,
        signature: base64UrlEncode(signatureTk),
        nonce: base64UrlEncode([0]),
        epoch: groupContextEpoch.toInt(),
        messageSequenceNumber: 0,
      );

      logger.i('Context epoch: $groupContextEpoch');

      for (final spFrame in result.spFrames) {
        logger.i("Frame epoch ${spFrame.frame.frame.epoch}");

        switch (spFrame.frame.frame.groupOperation.whichOperation()) {
          case GroupOperation_Operation.init:
            logger.d('init');
            break;
          case GroupOperation_Operation.addMember:
            logger.d('addmember');
            break;
          case GroupOperation_Operation.removeMember:
            logger.d('removeMember');
            break;
          case GroupOperation_Operation.keyUpdate:
            logger.d('keyupdate');
            break;
          case GroupOperation_Operation.leaveGroup:
            logger.d('leaveGroup');
            break;
          case GroupOperation_Operation.dropGroup:
            logger.d('dropGroup');
            break;
          case GroupOperation_Operation.notSet:
            logger.d('notSet, skipping');
            return;
        }

        final payload = groupContext!.processFrame(
          spFrame: spFrame.writeToBuffer(),
        );


      }
    } catch (e) {
      logger.e(e);
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
    // commit();
    DB.instance.updateDocumentContent(
      doc: doc!,
      parts: groupContext!.toParts(),
    );
    super.dispose();
  }
}
