import 'package:flutter/foundation.dart';
import 'package:uuid/v4.dart';
import 'package:zk_notion_app/api/client.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:zk_notion_app/storage/account_storage.dart';
import 'package:zk_notion_app/storage/models.dart';
import 'package:zk_notion_app/storage/sqlite/db.dart';
import 'package:zk_notion_app/utils/group_context_factory.dart';

class DocsPageViewModel extends ChangeNotifier {
  final _accStorage = AccountStorage();
  final List<Document> _docs = [];

  List<Document> get docs => List.unmodifiable(_docs);

  Future<void> loadDocuments() async {
    final loaded = await DB.instance.getDocumentList();
    _docs
      ..clear()
      ..addAll(loaded);
    notifyListeners();
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

    final doc = await DB.instance.transaction((db) async {
      final doc = await db.insertNewDocument(
        id: docID,
        title: resTitle,
        owner: ExternalAccount.fromAccount(owner),
        content: content,
      );

      final parts = GroupContextUtils.instance.intoParts(groupContext);
      await db.insertEpoch(groupId: docID, groupContext: parts);

      await GroupApiClient.instance.sendFrame(groupId: docID, frame: frame);

      return doc;
    });

    _docs.add(doc);
    notifyListeners();
  }

  Future<void> updateDoc(Document doc, {required String title}) async {
    final updated = Document(
      id: doc.id,
      title: title,
      automergeDoc: doc.automergeDoc,
      members: doc.members,
      createdAt: doc.createdAt,
      updatedAt: doc.updatedAt,
    );

    await DB.instance.updateDocumentTitle(updated);

    final index = _docs.indexWhere((d) => d.id == doc.id);
    if (index != -1) {
      _docs[index] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteDoc(Document doc) async {
    await DB.instance.deleteDocument(doc.id);
    _docs.removeWhere((d) => d.id == doc.id);
    notifyListeners();
  }
}
