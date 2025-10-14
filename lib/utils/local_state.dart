import 'package:uuid/v4.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/db.dart';

class LocalStateUtils {
  static final instance = LocalStateUtils._();

  LocalStateUtils._();

  Future<void> makeDocumentLocal(Document document) async {
    final oldId = document.id;
    final newId = UuidV4().generate();
    document.localOnly = true;
    document.id = newId;

    final localDocument = Document(
      automergeDoc: document.automergeDoc,
      id: newId,
      createdAt: document.createdAt,
      groupContextParts: document.groupContextParts,
      sequenceNumber: document.sequenceNumber,
      localOnly: true,
    );

    await DB.instance.deleteDocument(oldId);
    await DB.instance.insertDocument(document: localDocument);
  }
}
