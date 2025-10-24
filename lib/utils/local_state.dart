import 'package:hive_ce_flutter/hive_flutter.dart';
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

    // copy chat history to new document
    final oldBox = await Hive.openBox(oldId);
    final newBox = await Hive.openBox(newId);
    await newBox.putAll(oldBox.toMap());
    await oldBox.deleteFromDisk();

    await DB.instance.deleteDocument(oldId);
    await DB.instance.insertDocument(document: document);
  }
}
