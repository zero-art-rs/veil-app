import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:queue/queue.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:uuid/v4.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/sync_provider/events.dart';
import 'package:veil/managers/sync_provider/logger/logger.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/managers/sync_provider/sync_provider.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models/document_state.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/group_context_factory.dart';

class DocsPageViewModel extends ChangeNotifier {
  final _syncProvider = SyncProvider.instance;
  final _eventQueue = Queue();

  late StreamSubscription<List<SyncModel>> _docsListener;
  final _syncModelsListeners = <String, StreamSubscription<SyncModelEvent>>{};

  List<SyncModel> syncModels = [];

  Future<void> init() async {
    _syncProvider.subject.listen((event) {
      syncModels = event;

      _removeStaleListeners();
      _addNewListeners();

      notifyListeners();
    });
  }

  Future<void> createDoc(String title) async {
    final resTitle = title.isEmpty ? 'Document' : title;

    final docID = UuidV4().generate();
    final content = BAutoCommit.withOwner(
      actorId: AccountSecureStorage.instance.account.actorId,
    );

    final (groupContext, frame) = await GroupContextFactory.createGroupContext(
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

    final logger = Talker(
      logger: TalkerLogger(
        formatter: ColoredLoggerFormatter(),
        settings: TalkerLoggerSettings(defaultTitle: 'Sync model $docID'),
      ),
    );

    await _syncProvider.add(
      SyncModel(
        logger: SyncModelLogger(logger, document.id),
        documentState: document,
        groupContext: groupContext,
        localCrdtStorage: DB.instance,
      ),
      insertToDb: true,
    );
  }

  Future<void> deleteDoc(DocumentState doc) async {
    await _syncProvider.remove(doc.id);
    notifyListeners();
  }

  void _removeStaleListeners() {
    final existingIds = syncModels.map((e) => e.documentState.id).toSet();

    final removedIds = _syncModelsListeners.keys
        .where((id) => !existingIds.contains(id))
        .toList();

    for (final id in removedIds) {
      _syncModelsListeners[id]?.cancel();
      _syncModelsListeners.remove(id);
    }
  }

  void _addNewListeners() {
    for (final model in syncModels) {
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
        break;
    }
  }

  @override
  void dispose() {
    super.dispose();
    _docsListener.cancel();
    logger.info('Docs page disposed');
  }
}
