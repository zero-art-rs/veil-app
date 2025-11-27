import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:uuid/v4.dart';
import 'package:veil/storage/models/document_state.dart';
import 'package:veil/storage/sqlite/db.dart';

class LocalStateUtils {
  static final instance = LocalStateUtils._();

  LocalStateUtils._();

  Future<void> makeDocumentLocal(DocumentState document) async {
    final oldId = document.id;
    final newId = UuidV4().generate();
    document.isLocal = true;
    document.id = newId;

    // copy chat history to new document
    final oldBox = await Hive.openBox(oldId);
    final newBox = await Hive.openBox(newId);
    await newBox.putAll(oldBox.toMap());
    await oldBox.deleteFromDisk();

    await DB.instance.deleteDocumentState(oldId);
    await DB.instance.insertDocumentState(documentState: document);
  }
}
