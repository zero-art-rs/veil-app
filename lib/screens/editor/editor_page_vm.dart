import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/change_manager.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/screens/doc_members.dart';
import 'package:veil/screens/history_page.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/consts.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/editor_automerge.dart';
import 'package:veil/utils/group_context_factory.dart';
import 'package:veil/utils/payload.dart';

enum EditorModes { edit, view }

class EditorPageVm extends ChangeNotifier {
  final mdEditor = TextEditingController();
  final _changeManager = ChangeManager.instance;

  final SyncProviderModel syncModel;

  String? _hashBeforeEditing;
  StreamSubscription<SPFrame>? _subscription;
  bool isEditingFlow = false;
  bool isSinking = false;
  var selectedMode = EditorModes.view;
  final _crdtPayloadList = <ExposedCRDTPayload>[];

  EditorPageVm(this.syncModel);

  Future<void> init() async {
    syncModel.document.automergeDoc.setActorId(
      uuid: AccountSecureStorage.instance.account.actorId,
    );

    isSinking = true;
    notifyListeners();

    _subscription = _changeManager.stream(syncModel.document.id).listen((
      spFrame,
    ) async {
      final (crdtPayloads, fromCurrentUser) = processFrame(spFrame);

      if (fromCurrentUser) {
        logger.i('Received frame sent by current user, omitting...');
        return;
      }

      if (selectedMode == EditorModes.edit) {
        logger.i('Received document update, buffering it');
        _crdtPayloadList.addAll(crdtPayloads);
      }

      if (selectedMode != EditorModes.edit && crdtPayloads.isNotEmpty) {
        isSinking = true;
        notifyListeners();

        syncDocument(crdtPayloads);
        mdEditor.text = EditorAutomergeUtils.instance.toDoc(
          syncModel.document.automergeDoc,
        );

        logger.i(
          'Document state after sync ${syncModel.document.automergeDoc.getBlocks()}',
        );

        isSinking = false;
        notifyListeners();
      }

      await DB.instance.updateDocument(
        doc: syncModel.document,
        parts: syncModel.groupContext.asParts(),
      );
    });

    final frames = _changeManager.getFrames(syncModel.document.id);
    for (final frame in frames.values) {
      final (exposedCrdtPayload, _) = processFrame(frame);
      syncDocument(exposedCrdtPayload);
    }

    mdEditor.text = EditorAutomergeUtils.instance.toDoc(
      syncModel.document.automergeDoc,
    );

    await DB.instance.updateDocument(
      doc: syncModel.document,
      parts: syncModel.groupContext.asParts(),
    );

    isSinking = false;

    logger.i(
      'Init document state ${syncModel.document.automergeDoc.getBlocks()}',
    );

    notifyListeners();
  }

  void syncDocument(List<ExposedCRDTPayload> payloads) {
    for (final payload in payloads) {
      switch (payload.kind) {
        case ExposedCRDTPayloadKind.incrementalChange:
          final incrementalChange = payload.crdt.incrementalChange;
          syncModel.document.automergeDoc.loadIncremental(
            bytes: incrementalChange,
          );
        default:
      }
    }
  }

  (List<ExposedCRDTPayload> payloads, bool fromCurrentUser) processFrame(
    SPFrame spframe,
  ) {
    List<ExposedCRDTPayload> exposedCrdtPayload = [];

    final rawPayloads = syncModel.groupContext.processFrame(
      frame: spframe.frame.writeToBuffer(),
    );

    if (rawPayloads.isEmpty) {
      return ([], true);
    }

    for (final rawPayload in rawPayloads) {
      final payload = Payload.fromBuffer(rawPayload);

      final (crdt, _) = PayloadUtils.instance.exposePayload(payload);
      if (crdt == null) continue;

      exposedCrdtPayload.add(crdt);
    }

    syncModel.document.sequenceNumber = spframe.seqNum.toInt();
    return (exposedCrdtPayload, false);
  }

  void editMD() {
    notifyListeners();
  }

  Future<void> selectMode(EditorModes mode) async {
    selectedMode = mode;

    if (selectedMode != EditorModes.edit) {
      await editorTextSynchronize();

      _hashBeforeEditing = sha256
          .convert(utf8.encode(mdEditor.text))
          .toString();
    }

    notifyListeners();
  }

  Future<void> editorTextSynchronize() async {
    isSinking = true;
    notifyListeners();

    var hashAfterEditing = sha256
        .convert(utf8.encode(mdEditor.text))
        .toString();

    if (_hashBeforeEditing != hashAfterEditing) {
      EditorAutomergeUtils.instance.fromDoc(
        mdEditor.text,
        syncModel.document.automergeDoc,
      );
      syncModel.document.automergeDoc.commit();

      if (_crdtPayloadList.isNotEmpty) {
        logger.i('Syncing buffered changes..');
      }
      syncDocument(_crdtPayloadList);

      final saveIncremental = syncModel.document.automergeDoc.saveIncremental();
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
      syncModel.groupContext.commitState();

      await DB.instance.updateDocument(
        doc: syncModel.document,
        parts: syncModel.groupContext.asParts(),
      );

      logger.i(
        'Document state after changing mode ${syncModel.document.automergeDoc.getBlocks()}',
      );
    } else {
      if (_crdtPayloadList.isNotEmpty) {
        logger.i('Syncing buffered changes..');

        syncDocument(_crdtPayloadList);
        mdEditor.text = EditorAutomergeUtils.instance.toDoc(
          syncModel.document.automergeDoc,
        );

        _crdtPayloadList.clear();
      } else {
        logger.i('No buffered changes, no local changes, nothing to sync');
      }
    }

    isSinking = false;
    notifyListeners();
  }

  Future<List<MemberScreenModel>> prepareMembers() async {
    final groupInfo = syncModel.groupContext.retrieveGroupInfo();

    final members = groupInfo.members
        .map(
          (e) => MemberScreenModel(
            member: DocumentMember(
              account: ExternalAccount(
                actorId: e.id,
                name: e.name,
                rawPublicKey: e.publicKey,
              ),
              role: e.role.value,
              roleName: e.role.name,
            ),
            isYou: AccountSecureStorage.instance.account.actorId == e.id,
            isOwner: e.role.value == ownerRole,
          ),
        )
        .where((e) => e.member.account.name != 'Invited')
        .toList();

    return members;
  }

  List<ChangeEvent> prepareChanges() {
    final members = syncModel.groupContext.retrieveGroupInfo().members;

    return syncModel.document.automergeDoc
        .getChangeList()
        .indexed
        .map(
          (e) => ChangeEvent(
            title: 'Change',
            actorIdHex: e.$2.actorIdHex(),
            changeHashHex: e.$2.changeHash(),
            date: e.$2.timestamp(),
            name:
                members
                    .firstWhereOrNull((elem) => elem.id == e.$2.actorIdHex())
                    ?.name ??
                e.$2.actorIdHex(),
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

    if (_crdtPayloadList.isNotEmpty) {
      syncDocument(_crdtPayloadList);
    }

    await DB.instance.updateDocument(
      doc: syncModel.document,
      parts: syncModel.groupContext.asParts(),
    );
    super.dispose();
  }
}
