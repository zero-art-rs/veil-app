import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/v4.dart';
import 'package:zk_notion_app/api/client.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/managers/sync_provider.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:zk_notion_app/storage/account_storage.dart';
import 'package:zk_notion_app/storage/models.dart';
import 'package:zk_notion_app/utils/group_context_factory.dart';

class DocsPageViewModel extends ChangeNotifier {
  final _accStorage = AccountStorage();
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
      autoCommit: content,
    );

    final document = Document(
      id: docID,
      title: resTitle,
      automergeDoc: content,
      groupContextParts: groupContext.asParts(),
      createdAt: DateTime.now(),
    );

    await GroupApiClient.instance.sendFrame(groupId: docID, frame: frame);

    await _syncProvider.add(document, groupContext);
  }

  Future<void> updateDocumentName(Document doc, {required String title}) async {
    // await DB.instance.updateDocumentTitle(id: doc.id, title: title);

    // final index = _syncModels.indexWhere((d) => d.document.id == doc.id);
    // if (index != -1) {
    //   _docs[index] = Document(
    //     id: doc.id,
    //     title: title,
    //     automergeDoc: doc.automergeDoc,
    //     members: doc.members,
    //     createdAt: doc.createdAt,
    //     groupContextParts: doc.groupContextParts,
    //   );
    //   notifyListeners();
    // }
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
