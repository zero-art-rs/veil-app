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

    final document = Document(
      id: docID,
      title: resTitle,
      automergeDoc: content,
      groupContextParts: groupContext.toParts(),
      createdAt: DateTime.now(),
    );

    DB.instance.insertDocument(document: document);
    await GroupApiClient.instance.sendFrame(groupId: docID, frame: frame);

    _docs.add(document);
    notifyListeners();
  }

  Future<void> updateDocumentName(Document doc, {required String title}) async {
    await DB.instance.updateDocumentTitle(id: doc.id, title: title);

    final index = _docs.indexWhere((d) => d.id == doc.id);
    if (index != -1) {
      _docs[index] = Document(
        id: doc.id,
        title: title,
        automergeDoc: doc.automergeDoc,
        members: doc.members,
        createdAt: doc.createdAt,
        groupContextParts: doc.groupContextParts,
      );
      notifyListeners();
    }
  }

  Future<void> deleteDoc(Document doc) async {
    await DB.instance.deleteDocument(doc.id);
    _docs.removeWhere((d) => d.id == doc.id);
    notifyListeners();
  }
}
