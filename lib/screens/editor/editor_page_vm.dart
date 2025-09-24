import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zk_notion_app/api/client.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/managers/change_manager.dart';
import 'package:zk_notion_app/managers/sync_provider.dart';
import 'package:zk_notion_app/protos/zero_art.pb.dart';
import 'package:zk_notion_app/screens/doc_members.dart';
import 'package:zk_notion_app/screens/history_page.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:zk_notion_app/storage/account_storage.dart';
import 'package:zk_notion_app/storage/sqlite/db.dart';
import 'package:zk_notion_app/utils/editor_automerge.dart';
import 'package:zk_notion_app/utils/group_context_factory.dart';
import 'package:zk_notion_app/utils/payload.dart';

enum EditorModes { edit, view }

class EditorPageVm extends ChangeNotifier {
  final mdEditor = TextEditingController();
  final _accStorage = AccountStorage();
  final _changeManager = ChangeManager.instance;

  final SyncProviderModel syncModel;

  StreamSubscription<SPFrame>? _subscription;
  bool isEditingFlow = false;
  bool isSinking = false;
  var selectedMode = EditorModes.view;
  final _crdtPayloadList = <ExposedCRDTPayload>[];

  EditorPageVm(this.syncModel);

  Future<void> init() async {
    final account = await _accStorage.getAccount();

    if (account == null) {
      throw Exception('To open a document, you must have an account');
    }

    isSinking = true;
    notifyListeners();

    _subscription = _changeManager.stream(syncModel.document.id).listen((
      spFrame,
    ) {
      isSinking = true;
      notifyListeners();

      logger.i('Received new frame ${spFrame.seqNum}');
      final crdtPayloads = processFrame(spFrame);
      if (selectedMode == EditorModes.edit) {
        logger.i('received crdt payload');
        _crdtPayloadList.addAll(crdtPayloads);
      } else {
        mdEditor.text = EditorAutomergeUtils.instance.toDoc(
          syncModel.document.automergeDoc,
        );
      }

      isSinking = false;
      notifyListeners();
    });

    logger.i('init: Processing frames');
    final frames = _changeManager.getFrames(syncModel.document.id);
    for (final frame in frames.values) {
      logger.i('init: process frame');
      syncModel.groupContext.processFrame(spFrame: frame.writeToBuffer());
      print('init frame seq num ${syncModel.document.sequenceNumber}');
    }
    isSinking = false;

    syncModel.document.automergeDoc.setupBlockLabel();
    syncModel.document.automergeDoc.setActorId(uuid: account.actorId);

    mdEditor.text = EditorAutomergeUtils.instance.toDoc(
      syncModel.document.automergeDoc,
    );

    notifyListeners();
  }

  List<ExposedCRDTPayload> processFrame(SPFrame frame) {
    List<ExposedCRDTPayload> exposedCrdtPayload = [];

    final rawPayloads = syncModel.groupContext.processFrame(
      spFrame: frame.writeToBuffer(),
    );

    logger.i('rawPayloads.length editor ${rawPayloads.length}');
    for (final rawPayload in rawPayloads) {
      final payload = Payload.fromBuffer(rawPayload);

      final (crdt, _) = PayloadUtils.instance.exposePayload(payload);
      if (crdt == null) continue;

      exposedCrdtPayload.add(crdt);
    }

    syncModel.document.sequenceNumber = frame.seqNum.toInt();

    return exposedCrdtPayload;
  }

  void editMD() {
    notifyListeners();
  }

  void selectMode(EditorModes mode) {
    selectedMode = mode;

    if (selectedMode != EditorModes.edit) {
      synchronize();
    }

    notifyListeners();
  }

  void synchronize() async {
    logger.i('start sync');
    isSinking = true;
    notifyListeners();

    EditorAutomergeUtils.instance.fromDoc(
      mdEditor.text,
      syncModel.document.automergeDoc,
    );

    // does not commit if no changes in editor
    syncModel.document.automergeDoc.commit();

    for (final payload in _crdtPayloadList) {
      switch (payload.kind) {
        case ExposedCRDTPayloadKind.incrementalChange:
          final incrementalChange = payload.crdt.incrementalChange;
          syncModel.document.automergeDoc.loadIncremental(
            bytes: incrementalChange,
          );

          syncModel.document.automergeDoc.emptyChange();
          syncModel.document.automergeDoc.commit();
        default:
          logger.i('Received full doc, ignore');
        // case ExposedCRDTPayloadKind.fullDocument:
        //   syncModel.document.automergeDoc = BAutoCommit.load(
        //     data: payload.crdt.fullDocument,
        //   );
      }
    }

    final saveIncremental = syncModel.document.automergeDoc.saveIncremental();

    if (saveIncremental.isNotEmpty) {
      logger.i('Trying to send frame');
      await GroupApiClient.instance.sendFrame(
        groupId: syncModel.document.id,
        frame: syncModel.groupContext.createFrame(
          payloads: [
            Payload(
              crdt: CRDTPayload(incrementalChange: saveIncremental),
            ).writeToBuffer(),
          ],
        ),
      );
    }

    mdEditor.text = EditorAutomergeUtils.instance.toDoc(
      syncModel.document.automergeDoc,
    );

    isSinking = false;
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
  void dispose() async {
    _subscription?.cancel();

    await DB.instance.updateDocument(
      doc: syncModel.document,
      parts: syncModel.groupContext.asParts(),
    );
    super.dispose();
  }
}
