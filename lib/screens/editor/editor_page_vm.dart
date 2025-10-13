import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:async_queue/async_queue.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/screens/doc_members.dart';
import 'package:veil/screens/history_page.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/consts.dart';
import 'package:veil/utils/editor_automerge.dart';
import 'package:veil/utils/payload.dart';
import 'package:veil/widgets/banner.dart';

enum EditorModes { edit, view }

class EditorPageVm extends ChangeNotifier {
  final joinGroupLabel = 'joinGroup';
  final SyncModel syncModel;

  final mdEditor = TextEditingController();

  String? _documentContentBeforeEditing;
  bool isSinking = false;
  var selectedMode = EditorModes.view;
  bool allowWriteEvents = true;

  final crdtBufferController = StreamController<ExposedCRDTPayload>();
  late final crdtBuffer = StreamQueue(crdtBufferController.stream);

  final readEventQueue = AsyncQueue();
  final writeEventQueue = AsyncQueue();

  StreamSubscription? _removeFromGroupSubscription;
  StreamSubscription? _crdtUpdatesSubscription;

  EditorPageVm(this.syncModel);

  void init(BuildContext context) async {
    allowWriteEvents = !syncModel.isLocal;

    _removeFromGroupSubscription = syncModel.removedFromGroupEvent.listen((_) {
      if (context.mounted) _handleRemoveMember(context);
    });

    _crdtUpdatesSubscription = syncModel.crdtUpdatesEvent.listen((e) {
      mdEditor.text = EditorAutomergeUtils.instance.toText(e);
    });

    switch (syncModel.isLocal) {
      case true:
        _localInit();
      case false:
        _listenWriteQueueEvents();
        _listenReadQueueEvents();
        _joinGroupIfNeeded();
        await _networkInit(context);
    }
  }

  void _listenWriteQueueEvents() {
    writeEventQueue.addQueueListener((e) {
      if (e.jobLabel == joinGroupLabel) {
        final jobInfo = writeEventQueue.getJobInfo(joinGroupLabel);

        if (jobInfo.state == JobState.done) {
          allowWriteEvents = true;
          notifyListeners();
        }
      }
    });
  }

  void _listenReadQueueEvents() {
    readEventQueue.addQueueListener((e) {
      logger.i('Queue listener: ${e.currentQueueSize}');
      isSinking = !(e.currentQueueSize == 0);
      notifyListeners();
    });
  }

  void _joinGroupIfNeeded() {
    final userInGroup = syncModel.groupContext.retrieveGroupInfo().members.any(
      (e) => e.id == AccountSecureStorage.instance.account.actorId,
    );

    if (!userInGroup) {
      syncModel.sendJoinGroupFrame(AccountSecureStorage.instance.account);
    }
  }

  void _localInit() {
    mdEditor.text = EditorAutomergeUtils.instance.toText(
      syncModel.document.automergeDoc,
    );
    notifyListeners();
  }

  Future<void> _networkInit(BuildContext context) async {
    syncModel.document.automergeDoc.setActorId(
      uuid: AccountSecureStorage.instance.account.actorId,
    );

    mdEditor.text = EditorAutomergeUtils.instance.toText(
      syncModel.document.automergeDoc,
    );
    notifyListeners();
  }

  void _handleRemoveMember(BuildContext context) {
    allowWriteEvents = false;
    notifyListeners();
    logger.i('User removed from group, adding handling on ui');
    TopBanner.show(
      context: context,
      message: 'You have been removed from the group',
      kind: TopBannerCases.info,
    );
  }

  Future<void> selectMode(EditorModes mode) async {
    final runSync =
        selectedMode == EditorModes.edit && mode == EditorModes.view;

    if (selectedMode == EditorModes.edit) {
      syncModel.bufferFrames = true;
    }

    if (runSync) {
      await syncLocalAndNetworkState();
      syncModel.bufferFrames = false;
    }

    selectedMode = mode;

    notifyListeners();
  }

  Future<void> syncLocalAndNetworkState() async {
    var hashAfterEditing = sha256
        .convert(utf8.encode(mdEditor.text))
        .toString();

    if (_documentContentBeforeEditing != hashAfterEditing) {
      logger.i('Uploading new changes..');

      await syncModel.sendCrdtFrame(mdEditor.text);
      _documentContentBeforeEditing = sha256Hash(mdEditor.text);

      logger.i(
        'Document state after changing mode ${syncModel.document.automergeDoc.getBlocks()}',
      );
    } else {
      final crdtPayloadList = await _loadCrdtBuffer();

      if (crdtPayloadList.isNotEmpty) {
        logger.i('Syncing buffered changes..');

        mdEditor.text = await syncModel.appyCrdtListOperation(crdtPayloadList);
        _documentContentBeforeEditing = sha256Hash(mdEditor.text);
      } else {
        logger.i('No buffered changes, no local changes, nothing to sync');
      }
    }

    isSinking = false;
    notifyListeners();
  }

  Future<List<ExposedCRDTPayload>> _loadCrdtBuffer() async {
    final buffer = <ExposedCRDTPayload>[];

    while (await crdtBuffer.hasNext.timeout(
      Durations.short3,
      onTimeout: () => false,
    )) {
      buffer.add(await crdtBuffer.next);
    }
    return buffer;
  }

  String sha256Hash(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }

  void notify() {
    notifyListeners();
  }

  Future<List<MemberScreenModel>> prepareMemberList() async {
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

  List<ChangeEvent> prepareChangeList() {
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
  void dispose() {
    syncModel.bufferFrames = false;
    _crdtUpdatesSubscription?.cancel();
    _removeFromGroupSubscription?.cancel();
    super.dispose();
  }
}
