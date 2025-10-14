import 'package:uuid/v4.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/db.dart';

class LocalStateUtils {
  static final instance = LocalStateUtils._();

  LocalStateUtils._();

  Future<void> makeDocumentLocal(Document document) async {
    final newId = UuidV4().generate();
    document.localOnly = true;
    document.id = newId;

    final localDocument = Document(
      automergeDoc: document.automergeDoc,
      id: UuidV4().generate(),
      createdAt: document.createdAt,
      groupContextParts: document.groupContextParts,
      sequenceNumber: document.sequenceNumber,
      localOnly: true,
    );

    await DB.instance.deleteDocument(document.id);
    await DB.instance.insertDocument(document: localDocument);
  }
}
