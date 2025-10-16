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
  final _syncProvider = SyncProvider.instance;

  late StreamSubscription<List<SyncModel>> _docsListener;
  List<SyncModel> syncModels = [];

  Future<void> sink() async {
    _docsListener = _syncProvider.subject.listen((event) {
      syncModels = event;
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

    final document = Document(
      id: docID,
      createdAt: DateTime.now(),
      automergeDoc: content,
      groupContextParts: await groupContext.asParts(),
    );

    await GroupApiClient.instance.sendFrame(groupId: docID, frame: frame);
    await _syncProvider.add(document, groupContext, insertToDb: true);
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
