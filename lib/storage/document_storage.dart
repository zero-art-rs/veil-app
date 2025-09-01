import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:zk_notion_app/storage/app_storage.dart';
import 'package:zk_notion_app/storage/models.dart';

class DocumentStorage {
  final _storage = AppStorage();
  static const String _documentsKey = 'documents';

  Future<Document> createDocument({
    required String title,
    required String owner,
  }) async {
    final autocommit = BAutoCommit();

    final document = Document.withGeneratedId(
      title: title,
      owner: owner,
      content: autocommit,
    );

    final docs = await getDocuments();
    if (docs.isEmpty) {
      await _storage.setArray(_documentsKey, [document.toJson()]);
    } else {
      await _storage.appendToArray(_documentsKey, document.toJson());
    }

    return document;
  }

  Future<List<Document>> getDocuments() async {
    final rawDocs = await _storage.getObjectArray(_documentsKey);
    return rawDocs.map((e) => Document.fromJson(e)).toList();
  }

  Future<void> updateDocument(Document document) async {
    await _storage.updateWhere(
      _documentsKey,
      (e) => document.id == e['id'],
      document.toJson(),
    );
  }

  removeDocument(String id) async {
    await _storage.removeWhere(_documentsKey, (elem) => elem['id'] == id);
  }
}
