import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/utils/editor_automerge.dart';
import 'package:veil/widgets/banner.dart';

enum EditorModes { edit, view }

class EditorPageVm extends ChangeNotifier {
  final SyncModel syncModel;
  final mdEditor = TextEditingController();

  String? _documentContentBeforeEditing;
  bool isSinking = false;
  var selectedMode = EditorModes.view;
  bool allowWriteEvents = true;

  final groupNameController = TextEditingController();
  StreamSubscription? _isProcessingSubscription;
  StreamSubscription? _removeFromGroupSubscription;
  StreamSubscription? _crdtUpdatesSubscription;
  StreamSubscription? _groupInfoUpdatesEventSubscription;
  Timer? _waitForJoinGroupTicker;

  EditorPageVm(this.syncModel);

  void init(BuildContext context) async {
    allowWriteEvents = !syncModel.isLocal;

    groupNameController.text = syncModel.groupContext.retrieveGroupInfo().name;

    _groupInfoUpdatesEventSubscription = syncModel.groupInfoUpdateEvent.listen((
      e,
    ) {
      groupNameController.text = syncModel.groupContext
          .retrieveGroupInfo()
          .name;
    });

    _isProcessingSubscription = syncModel.isProcessing.listen((e) {
      isSinking = e;
      notifyListeners();
    });

    _removeFromGroupSubscription = syncModel.removedFromGroupEvent.listen((_) {
      if (context.mounted) _handleRemoveMember(context);
    });

    _crdtUpdatesSubscription = syncModel.crdtUpdatesEvent.listen((e) {
      mdEditor.text = EditorAutomergeUtils.instance.toText(e);
      _documentContentBeforeEditing = sha256Hash(mdEditor.text);
      notifyListeners();
    });

    switch (syncModel.isLocal) {
      case true:
        _localInit();
      case false:
        await _joinGroupIfNeeded(context);
        await _networkInit();
    }

    notifyListeners();
  }

  Future<void> updateGroupName(BuildContext context, String groupName) async {
    try {
      await syncModel.updateGroupName(name: groupNameController.text);
    } catch (e) {
      logger.e('Failed to update group name: $e');
      if (!context.mounted) return;
      TopBanner.show(
        context: context,
        message: 'Failed to update group name',
        kind: TopBannerCases.error,
      );
    }
  }

  Future<void> _joinGroupIfNeeded(BuildContext context) async {
    if (!syncModel.isUserInGroup()) {
      allowWriteEvents = false;
      try {
        await syncModel.sendJoinGroupFrame(
          AccountSecureStorage.instance.account,
        );
        _startWaitForJoinGroupTicker();
      } catch (e) {
        logger.e('Failed to join group: $e');
        if (!context.mounted) return;
        TopBanner.show(
          context: context,
          message: 'Failed to join group',
          kind: TopBannerCases.error,
        );
      }
    }
  }

  void _startWaitForJoinGroupTicker() {
    _waitForJoinGroupTicker = Timer.periodic(Duration(seconds: 1), (_) {
      if (syncModel.isUserInGroup()) {
        _waitForJoinGroupTicker?.cancel();
        allowWriteEvents = true;
        notifyListeners();
      }
    });
  }

  void _localInit() {
    mdEditor.text = EditorAutomergeUtils.instance.toText(
      syncModel.document.automergeDoc,
    );
    notifyListeners();
  }

  Future<void> _networkInit() async {
    syncModel.document.automergeDoc.setActorId(
      uuid: AccountSecureStorage.instance.account.actorId,
    );

    mdEditor.text = EditorAutomergeUtils.instance.toText(
      syncModel.document.automergeDoc,
    );

    _documentContentBeforeEditing = sha256Hash(mdEditor.text);
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

    if (mode == EditorModes.edit) {
      logger.d('Bufferizing frames trigger on ui');
      syncModel.bufferizeFrames();
    }

    if (runSync) {
      await syncLocalAndNetworkState();
    }

    selectedMode = mode;
    notifyListeners();
  }

  Future<void> syncLocalAndNetworkState() async {
    var documentContentAfterEditing = sha256
        .convert(utf8.encode(mdEditor.text))
        .toString();

    if (_documentContentBeforeEditing != documentContentAfterEditing) {
      await syncModel.sendCrdtFrame(mdEditor.text);
    }

    await syncModel.applyBufferedFrames();
  }

  String sha256Hash(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }

  void notify() {
    notifyListeners();
  }

  @override
  void dispose() {
    syncModel.applyBufferedFrames();
    _isProcessingSubscription?.cancel();
    _crdtUpdatesSubscription?.cancel();
    _removeFromGroupSubscription?.cancel();
    _groupInfoUpdatesEventSubscription?.cancel();
    super.dispose();
  }
}
