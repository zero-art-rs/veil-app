import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:htmltopdfwidgets/htmltopdfwidgets.dart' as html2pdf;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/utils/editor_automerge.dart';
import 'package:veil/utils/markdown_2_pdf.dart';
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

  Future<void> previewPdf(BuildContext parentContext) async {
    final pdf = await Markdown2PdfUtils.instance.convert(mdEditor.text);

    if (!parentContext.mounted) return;
    showDialog(
      context: parentContext,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(20),
        child: SizedBox(
          width: MediaQuery.of(context).size.width / 2,
          height: MediaQuery.of(context).size.height / 2 * 3,
          child: PdfPreview(
            build: (format) => pdf.save(),
            allowSharing: true,
            allowPrinting: false,
            canDebug: false,
            canChangeOrientation: false,
            pdfFileName: groupNameController.text,
            actions: [
              IconButton(
                onPressed: () async {
                  await _savePdf(context, pdf);
                },
                icon: Icon(Icons.save_alt_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setCorrupted() {
    allowWriteEvents = false;
    documentStatus = EditorDocumentStatus.corrupted;
    notifyListeners();
  }

  Future<void> _savePdf(
    BuildContext context,
    html2pdf.Document document,
  ) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final file = File('${documentsDir.path}/${groupNameController.text}.pdf');
    await file.writeAsBytes(await document.save());

    if (!context.mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF file saved'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () {
            OpenFilex.open(documentsDir.path);
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
    _corruptedEventSubscription?.cancel();
    _isProcessingSubscription?.cancel();
    _crdtUpdatesSubscription?.cancel();
    _removeFromGroupSubscription?.cancel();
    _groupInfoUpdatesEventSubscription?.cancel();
    super.dispose();
  }
}
