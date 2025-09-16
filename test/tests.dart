import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';
import 'package:zk_notion_app/src/rust/frb_generated.dart';
import 'package:zk_notion_app/storage/models.dart';
import 'package:zk_notion_app/storage/sqlite/db.dart';

import 'db_test_helpers.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'Create document, document members, accounts, remove document and check cascade',
    () async {
      databaseFactory = databaseFactoryFfi;
      final db = DB.instance;
      await db.open(inMemoryPath: inMemoryDatabasePath);

      final doc = await insertNewDocument(db);

      insertFamiliarDocumentMember(db, doc.id);
      insertFamiliarDocumentMember(db, doc.id);

      expect(getContactList(db), List.empty());

      await db.deleteDocument(doc.id);
    },
  );
}

deserializeMarkdownTest() {
  final markdown = """
  # HEADING

  - [ ] FEFMKERFMERKMF
  - [ ] FEFMKERFMERKMF
  - [ ] FEFMKERFMERKMF

  ferl;fle;rfl,erfl,erl,;
  """;
  final doc = deserializeMarkdownToDocument(markdown);

  print(doc);
}

databaseTest() {}
