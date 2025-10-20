import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/v4.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/managers/sync_provider/sync_provider.dart';
import 'package:veil/screens/account_page.dart';
import 'package:veil/screens/editor/editor_page.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/utils/group_context_factory.dart';
import 'package:veil/widgets/banner.dart';

import '../../main.dart';

class PrimaryPageViewModel extends ChangeNotifier {
  final _syncProvider = SyncProvider.instance;

  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  Widget _selectedPage = AccountPage();
  Widget get selectedPage => _selectedPage;

  List<SyncModel> _syncModels = [];
  List<SyncModel> get syncModels => _syncModels;

  final TextEditingController textEditingController = TextEditingController();
  final _syncModelUiUpdatesListeners = <String, StreamSubscription<bool>>{};

  static const constantTabs = 5;

  void init() async {
    _syncProvider.subject.listen((event) {
      _syncModels = event;

      // remove listeners for removed sync models
      _syncModelUiUpdatesListeners.keys
          .where((key) => !_syncModels.map((e) => e.document.id).contains(key))
          .forEach((key) {
            _syncModelUiUpdatesListeners[key]?.cancel();
          });

      // add listeners for new sync models
      for (final syncModel in _syncModels) {
        if (_syncModelUiUpdatesListeners[syncModel.document.id] == null) {
          _syncModelUiUpdatesListeners[syncModel.document.id] = syncModel
              .groupInfoUpdateEvent
              .listen((event) => notifyListeners());
        }
      }

      notifyListeners();
    });
  }

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  Future<void> createDocument(BuildContext context) async {
    try {
      final resTitle = textEditingController.text.isEmpty
          ? 'Document'
          : textEditingController.text;

      final docID = UuidV4().generate();
      final content = BAutoCommit.withOwner(
        actorId: AccountSecureStorage.instance.account.actorId,
      );

      final (
        groupContext,
        frame,
      ) = await GroupContextFactory.createGroupContext(
        groupName: resTitle,
        groupID: docID,
        owner: AccountSecureStorage.instance.account,
      );

      final document = Document(
        id: docID,
        createdAt: DateTime.now(),
        automergeDoc: content,
        groupContextParts: await groupContext.asParts(),
      );

      await GroupApiClient.instance.sendFrame(groupId: docID, frame: frame);
      await _syncProvider.add(document, groupContext, insertToDb: true);
      textEditingController.clear();

      notifyListeners();
    } catch (err) {
      logger.e('Failed to create document: $err');
      if (!context.mounted) return;
      TopBanner.show(
        context: context,
        message: 'Failed to create document',
        kind: TopBannerCases.error,
      );
    }
  }

  void setSelectedPage(Widget page) {
    _selectedPage = page;
    notifyListeners();
  }

  Future<void> removeDocument(BuildContext context, String id) async {
    try {
      final index = _syncModels.indexWhere(
        (element) => element.document.id == id,
      );
      if (index == -1) throw FormatException('Document not found');

      await _syncProvider.remove(id);
      _syncModels.removeWhere((element) => element.document.id == id);

      if (_syncModels.isEmpty) {
        setSelectedIndex(0);
        setSelectedPage(AccountPage());
      } else if (index > 0) {
        setSelectedIndex(constantTabs + index - 1);
        setSelectedPage(EditorPage(syncModel: _syncModels[index - 1]));
      } else {
        setSelectedIndex(constantTabs + 1);
        setSelectedPage(EditorPage(syncModel: _syncModels.first));
      }

      notifyListeners();
    } catch (err) {
      logger.e('Failed to remove document: $err');
      if (!context.mounted) return;

      TopBanner.show(
        context: context,
        message: 'Failed to remove document',
        kind: TopBannerCases.error,
      );
    }
  }
}
