import 'dart:async';

import 'package:flutter/material.dart';
import 'package:queue/queue.dart';
import 'package:uuid/v4.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/managers/sync_provider/events.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/managers/sync_provider/sync_provider.dart';
import 'package:veil/screens/account_page.dart';
import 'package:veil/screens/editor_container/editor_container_page.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models/document_state.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/group_context_factory.dart';
import 'package:veil/widgets/banner.dart';

import '../../main.dart';

class PrimaryPageViewModel extends ChangeNotifier {
  final _syncProvider = SyncProvider.instance;
  final _eventQueue = Queue();

  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  Widget _selectedPage = AccountPage();
  Widget get selectedPage => _selectedPage;

  List<SyncModel> _syncModels = [];
  List<SyncModel> get syncModels => _syncModels;

  final TextEditingController textEditingController = TextEditingController();
  final _syncModelsListeners = <String, StreamSubscription<SyncModelEvent>>{};

  static const constantTabs = 5;

  void init() async {
    _syncProvider.subject.listen((event) {
      _syncModels = event;

      _removeStaleListeners();
      _addNewListeners();

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

      final document = DocumentState(
        id: docID,
        createdAt: DateTime.now(),
        crdt: content,
        groupContextParts: await groupContext.asParts(),
      );

      await GroupApiClient.instance.sendFrame(groupId: docID, frame: frame);
      await _syncProvider.add(
        SyncModel(
          documentState: document,
          groupContext: groupContext,
          localCrdtStorage: DB.instance,
        ),
        insertToDb: true,
      );
      textEditingController.clear();

      notifyListeners();
    } catch (err, st) {
      logger.error('Failed to create document', err, st);
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
        (element) => element.documentState.id == id,
      );
      if (index == -1) throw FormatException('Document not found');

      await _syncProvider.remove(id);
      _syncModels.removeWhere((element) => element.documentState.id == id);

      if (_syncModels.isEmpty) {
        setSelectedIndex(0);
        setSelectedPage(AccountPage());
      } else if (index > 0) {
        setSelectedIndex(constantTabs + index - 1);
        setSelectedPage(EditorContainerPage(syncModel: _syncModels[index - 1]));
      } else {
        setSelectedIndex(constantTabs + 1);
        setSelectedPage(EditorContainerPage(syncModel: _syncModels.first));
      }

      notifyListeners();
    } catch (err, st) {
      logger.error('Failed to remove document', err, st);
      if (!context.mounted) return;

      TopBanner.show(
        context: context,
        message: 'Failed to remove document',
        kind: TopBannerCases.error,
      );
    }
  }

  void _removeStaleListeners() {
    final existingIds = _syncModels.map((e) => e.documentState.id).toSet();

    final removedIds = _syncModelsListeners.keys
        .where((id) => !existingIds.contains(id))
        .toList();

    for (final id in removedIds) {
      _syncModelsListeners[id]?.cancel();
      _syncModelsListeners.remove(id);
    }
  }

  void _addNewListeners() {
    for (final model in _syncModels) {
      final id = model.documentState.id;

      if (_syncModelsListeners.containsKey(id)) continue;

      _syncModelsListeners[id] = model.eventStream.listen((event) {
        _eventQueue.add(() async {
          _handleSyncEvent(event);
        });
      });
    }
  }

  void _handleSyncEvent(SyncModelEvent e) {
    switch (e) {
      case SyncModelGroupInfoEvent():
      case SyncModelCorruptedEvent():
      case SyncModelSyncingEvent():
        notifyListeners();
    }
  }
}
