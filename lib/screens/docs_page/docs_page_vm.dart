import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/v4.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/managers/sync_provider/sync_provider.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/utils/group_context_factory.dart';

class DocsPageViewModel extends ChangeNotifier {
  final _accStorage = AppSecureStorage();
  final _syncProvider = SyncProvider.instance;

  late StreamSubscription<List<SyncProviderModel>> _docsListener;
  List<SyncProviderModel> syncModels = [];

  Future<void> sink() async {
    _docsListener = _syncProvider.subject.listen((event) {
      syncModels = event;
      notifyListeners();
    });
  }

  Future<void> createDoc(String title) async {
    final resTitle = title.isEmpty ? 'Document' : title;
    final owner = await _accStorage.getAccount();

    if (owner == null) {
      throw Exception('To create a document, you must have an account');
    }

    final docID = UuidV4().generate();
    final content = BAutoCommit();

    final (groupContext, frame) = GroupContextFactory.createGroupContext(
      groupName: resTitle,
      groupID: docID,
      owner: owner,
    );

    final document = Document(
      id: docID,
      createdAt: DateTime.now(),
      automergeDoc: content,
      groupContextParts: groupContext.asParts(),
    );

    await GroupApiClient.instance.sendFrame(groupId: docID, frame: frame);

    await _syncProvider.add(document, groupContext);
  }

  Future<void> deleteDoc(Document doc) async {
    await _syncProvider.remove(doc.id);
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
    _docsListener.cancel();
    logger.i('Docs page disposed');
  }
}
