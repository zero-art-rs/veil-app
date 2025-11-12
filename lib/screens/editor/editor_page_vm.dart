import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_2_pdf/markdown_2_pdf.dart';
import 'package:open_filex/open_filex.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/utils/editor_automerge.dart';
import 'package:veil/utils/platform.dart';
import 'package:veil/widgets/banner.dart';

enum EditorModes { edit, view }

enum EditorDocumentStatus { local, network, corrupted }

class EditorPageVm extends ChangeNotifier {
  final SyncModel syncModel;
  final mdEditor = TextEditingController();

  String? _documentContentBeforeEditing;
  bool isSinking = false;
  var selectedMode = EditorModes.view;
  bool allowWriteEvents = true;
  EditorDocumentStatus documentStatus = EditorDocumentStatus.network;

  final groupNameController = TextEditingController();
  StreamSubscription? _isProcessingSubscription;
  StreamSubscription? _removeFromGroupSubscription;
  StreamSubscription? _crdtUpdatesSubscription;
  StreamSubscription? _groupInfoUpdatesEventSubscription;
  StreamSubscription? _corruptedEventSubscription;
  Timer? _waitForJoinGroupTicker;

  EditorPageVm(this.syncModel);

  void init(BuildContext context) async {
    allowWriteEvents = !syncModel.isLocal;

    groupNameController.text = syncModel.groupContext.retrieveGroupInfo().name;

    _corruptedEventSubscription = syncModel.corruptedEvent.listen((e) {
      _setCorrupted();
    });

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

    if (syncModel.isLocal) {
      documentStatus = EditorDocumentStatus.local;
    }

    if (syncModel.corrupted) {
      documentStatus = EditorDocumentStatus.corrupted;
    }

    switch (documentStatus) {
      case EditorDocumentStatus.local:
        _localInit();
      case EditorDocumentStatus.network:
        await _joinGroupIfNeeded(context);
        await _networkInit();
      case EditorDocumentStatus.corrupted:
        _setCorrupted();
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

  void _setCorrupted() {
    allowWriteEvents = false;
    documentStatus = EditorDocumentStatus.corrupted;
    mdEditor.text = EditorAutomergeUtils.instance.toText(
      syncModel.documentState.crdt,
    );

    notifyListeners();
  }

  Future<void> exportPDF(BuildContext context) async {
    final converter = MarkdownToPdfConverter(
      options: PredefinedPdfOptions.academicOptions,
    );

    final pdf = await converter.convertToFile(
      StringMarkdownSource(mdEditor.text),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF file saved'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () {
            OpenFilex.open(pdf.path);
          },
        ),
      ),
    );
  }

  void copyMd(BuildContext context) {
    Clipboard.setData(ClipboardData(text: mdEditor.text));

    TopBanner.show(
      context: context,
      message: 'Markdown is copied to clipboard',
      kind: TopBannerCases.info,
    );
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
      syncModel.documentState.crdt,
    );
    notifyListeners();
  }

  Future<void> _networkInit() async {
    syncModel.documentState.crdt.setActorId(
      uuid: AccountSecureStorage.instance.account.actorId,
    );

    mdEditor.text = EditorAutomergeUtils.instance.toText(
      syncModel.documentState.crdt,
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

  Map<ShortcutActivator, void Function()> saveActionWidget(
    BuildContext context,
  ) {
    final handleOnSaveAction = () async {
      if (selectedMode == EditorModes.edit) {
        await selectMode(context, EditorModes.view);
      }
    };

    final map = <ShortcutActivator, VoidCallback>{};
    if (PlatformUtils.isMacOS) {
      map[const SingleActivator(LogicalKeyboardKey.keyS, meta: true)] =
          handleOnSaveAction;
    } else {
      map[const SingleActivator(LogicalKeyboardKey.keyS, control: true)] =
          handleOnSaveAction;
    }

    return map;
  }

  Future<void> selectMode(BuildContext context, EditorModes mode) async {
    final runSync =
        selectedMode == EditorModes.edit && mode == EditorModes.view;

    if (mode == EditorModes.edit) {
      logger.d('Bufferizing frames trigger on ui');
      await syncModel.bufferizeFrames();
    }

    if (runSync) {
      try {
        await syncLocalAndNetworkState();
      } catch (e) {
        logger.e('Failed to sync local and network state: $e');

        if (!context.mounted) return;

        TopBanner.show(
          context: context,
          message: 'Failed to sync local and network state',
          kind: TopBannerCases.error,
        );
      }
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
    _corruptedEventSubscription?.cancel();
    _isProcessingSubscription?.cancel();
    _crdtUpdatesSubscription?.cancel();
    _removeFromGroupSubscription?.cancel();
    _groupInfoUpdatesEventSubscription?.cancel();
    super.dispose();
  }
}
