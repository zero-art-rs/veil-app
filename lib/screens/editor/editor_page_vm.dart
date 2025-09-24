import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:zk_notion_app/api/client.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/managers/sync_provider.dart';
import 'package:zk_notion_app/protos/zero_art.pb.dart';
import 'package:zk_notion_app/screens/doc_members.dart';
import 'package:zk_notion_app/screens/history_page.dart';
import 'package:zk_notion_app/storage/account_storage.dart';
import 'package:zk_notion_app/storage/sqlite/db.dart';
import 'package:zk_notion_app/utils/editor_automerge.dart';
import 'package:zk_notion_app/utils/group_context_factory.dart';

class EditorPageVm extends ChangeNotifier {
  final mdEditor = TextEditingController();
  final _accStorage = AccountStorage();

  final editModes = ["edit", "view"];
  var selectedMode = "view";

  bool get isEditView => selectedMode == "edit";
  final SyncProviderModel syncModel;

  StreamSubscription<SSEModel>? _centrifugoSubscription;
  bool isProcessingFrames = false;

  EditorPageVm(this.syncModel);

  Future<void> init() async {
    final account = await _accStorage.getAccount();

    if (account == null) {
      throw Exception('To open a document, you must have an account');
    }

    syncModel.document.automergeDoc.setupBlockLabel();
    syncModel.document.automergeDoc.setActorId(uuid: account.actorId);

    mdEditor.text = EditorAutomergeUtils.instance.toDoc(
      syncModel.document.automergeDoc,
    );

    notifyListeners();
  }

  void editMD() {
    notifyListeners();
  }

  Future<void> commit() async {
    final incrementalChange = syncModel.document.automergeDoc.saveIncremental();
    if (incrementalChange.isEmpty) return;

    logger.i('--- COMMIT --- ');
    logger.i('Sending incremental change...');

    final payload = Payload(
      crdt: CRDTPayload(incrementalChange: incrementalChange),
    ).writeToBuffer();

    final frame = syncModel.groupContext.createFrame(payloads: [payload]);
    await GroupApiClient.instance.sendFrame(
      groupId: syncModel.document.id,
      frame: frame,
    );

    syncModel.document.automergeDoc.commit();
  }

  void selectMode(String mode) {
    selectedMode = mode;
    notifyListeners();
  }

  Future<List<MemberScreenModel>> prepareMembers() async {
    final account = await _accStorage.getAccount();
    return syncModel.document.members
        .map(
          (e) => MemberScreenModel(
            member: e,
            isYou: e.account.actorId == account?.actorId,
          ),
        )
        .toList();
  }

  List<ChangeEvent> prepareChanges() {
    return syncModel.document.automergeDoc
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
    _centrifugoSubscription?.cancel();
    commit();
    DB.instance.updateDocument(
      doc: syncModel.document,
      parts: syncModel.groupContext.asParts(),
    );
    super.dispose();
  }
}
