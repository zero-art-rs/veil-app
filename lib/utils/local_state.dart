import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/db.dart';

class LocalStateUtils {
  static final instance = LocalStateUtils();

  Future<void> makeDocumentLocal(Document document) async {
    document.localOnly = true;
    await DB.instance.makeDocumentLocalOnly(id: document.id);
  }
}
