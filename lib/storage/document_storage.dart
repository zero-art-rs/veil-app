import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:zk_notion_app/storage/app_storage.dart';
import 'package:zk_notion_app/storage/models.dart';

class DocumentStorage {
  final _storage = AppStorage();
  static const String _documentsKey = 'documents';

  clear() {
    _storage.setArray(_documentsKey, []);
  }

  Future<Document> createDocument({
    required String title,
    required DocumentMember owner,
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

  /// Returns true if member already exists
  Future<bool> addMember(String id, DocumentMember member) async {
    final document = await _storage.getObject(
      key: _documentsKey,
      condition: (e) => e['id'] == id,
    );

    if (document == null) throw FormatException('Member not found');

    final documentMembers = document['members'] as List<dynamic>;
    if (documentMembers.any(
      (e) => e['account']['actorId'] == member.account.actorId,
    )) {
      return true;
    }

    document['members'].add(member.toJson());
    await _storage.updateWhere(_documentsKey, (e) => e['id'] == id, document);

    return false;
  }

  Future<void> removeMember(String id, String actorId) async {
    final document = await _storage.getObject(
      key: _documentsKey,
      condition: (e) => e['id'] == id,
    );

    if (document == null) throw FormatException('Member not found');
    document['members'].removeWhere((e) => e['account']['actorId'] == actorId);
    await _storage.updateWhere(_documentsKey, (e) => e['id'] == id, document);
  }

  removeDocument(String id) async {
    await _storage.removeWhere(_documentsKey, (elem) => elem['id'] == id);
  }
}
