import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:zk_notion_app/api/client.dart';
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

    _saveTicker = Timer.periodic(const Duration(seconds: 3), (_) => commit());
    notifyListeners();
  }

  Future<void> commit() async {
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
    commit();
    DB.instance.updateDocumentContent(
      doc: doc!,
      parts: groupContext!.toParts(),
    );
    super.dispose();
  }
}
