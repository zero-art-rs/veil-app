import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:zk_notion_app/storage/models.dart';
import 'package:zk_notion_app/storage/sqlite/models/account.dart';
import 'package:zk_notion_app/storage/sqlite/consts.dart';
import 'package:zk_notion_app/storage/sqlite/models/document.dart';
import 'package:zk_notion_app/storage/sqlite/schemes.dart';
import 'package:zk_notion_app/utils/group_context_factory.dart';

const _dbName = 'veil.db';

class DB {
  static final instance = DB._internal();
  DB._internal();

  late Database _connection;
  Transaction? _tx;

  Future<void> open({String? inMemoryPath}) async {
    _connection = await openDatabase(
      inMemoryPath ?? _dbName,
      version: 1,
      readOnly: false,
      onConfigure: (db) {
        db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute(createContactsTable);
        await db.execute(createContactsSpksTable);
        await db.execute(createDocumentsTable);
      },
    );
  }

  Future<T> transaction<T>(Future<T> Function(DB db) action) async {
    if (!_connection.isOpen) {
      throw Exception('Connection is closed');
    }

    return await _connection.transaction((tx) async {
      final nested = DB._withTransaction(_connection, tx);
      return await action(nested);
    });
  }

  DB._withTransaction(this._connection, this._tx);

  // -------------------------------------------------
  // CRUD helpers
  // -------------------------------------------------

  Future<List<Map<String, Object?>>> _query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final executor = _tx ?? _connection;
    return await executor.query(
      table,
      distinct: distinct ?? false,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> _insert(
    String table,
    Map<String, Object?> data, {
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort,
  }) async {
    final executor = _tx ?? _connection;
    return await executor.insert(
      table,
      data,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<int> _delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final executor = _tx ?? _connection;
    return await executor.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<int> _update(
    String table,
    Map<String, Object?> data, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final executor = _tx ?? _connection;
    return await executor.update(
      table,
      data,
      where: where,
      whereArgs: whereArgs,
    );
  }

  // -------------------------------------------------
  // High-level API
  // -------------------------------------------------

  Future<void> removeAll() {
    return transaction((db) async {
      await db._delete(contactsTable);
      await db._delete(contactsSpksTable);
      await db._delete(documentsTable);
    });
  }

  Future<void> insertContact(
    ExternalAccount account, {
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.rollback,
  }) async {
    final sqlAccount = SQLAccount(
      actorId: account.actorId,
      publicKey: Uint8List.fromList(account.rawPublicKey),
      name: account.name,
      kind: AccountKind.contact.name,
    );

    await _insert(
      contactsTable,
      sqlAccount.toJson(),
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<void> deleteContact({required String actorId}) async {
    await _delete(contactsTable, where: 'actor_id = ?', whereArgs: [actorId]);
  }

  Future<List<ExternalAccount>> getContactList() async {
    final rawAccounts = await _query(
      contactsTable,
      whereArgs: [AccountKind.contact.name],
    );

    final sqlAccounts = rawAccounts.map((e) => SQLAccount.fromJson(e)).toList();

    return sqlAccounts
        .map(
          (e) => ExternalAccount(
            actorId: e.actorId,
            rawPublicKey: e.publicKey,
            name: e.name,
          ),
        )
        .toList();
  }

  Future<List<Document>> getDocumentList() async {
    final rawDocuments = await _connection.rawQuery(
      "SELECT * FROM documents ORDER BY created_at ASC",
    );

    final sqlDocuments = rawDocuments
        .map((e) => SQLDocument.fromJson(e))
        .toList();

    final documents = sqlDocuments
        .map(
          (doc) => Document(
            id: doc.id,
            title: doc.title,
            automergeDoc: BAutoCommit.fromBytes(bytes: doc.content),
            createdAt: doc.createdAt,
            groupContextParts: GroupContextParts.fromJsonString(
              doc.groupContextParts,
            ),
            sequenceNumber: doc.sequenceNumber,
          ),
        )
        .toList();

    return documents;
  }

  Future<Document?> getDocumentById(String id) async {
    final rawDocument = await _connection.query(
      documentsTable,
      where: 'id = ?',
      whereArgs: [id],
      orderBy: 'created_at ASC',
    );

    if (rawDocument.isEmpty) return null;

    final doc = SQLDocument.fromJson(rawDocument.first);

    return Document(
      id: doc.id,
      title: doc.title,
      automergeDoc: BAutoCommit.fromBytes(bytes: doc.content),
      createdAt: doc.createdAt,
      groupContextParts: GroupContextParts.fromJsonString(
        doc.groupContextParts,
      ),
    );
  }

  Future<void> insertDocument({required Document document}) async {
    final sqlDoc = SQLDocument(
      id: document.id,
      title: document.title,
      content: document.automergeDoc.save(),
      createdAt: document.createdAt,
      groupContextParts: document.groupContextParts.toJsonString(),
      sequenceNumber: document.sequenceNumber,
    );

    await _insert(
      documentsTable,
      sqlDoc.toJson(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> updateDocumentTitle({
    required String id,
    required String title,
  }) async {
    await _update(
      documentsTable,
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateDocument({
    required Document doc,
    required GroupContextParts parts,
  }) async {
    await _update(
      documentsTable,
      {
        'content': doc.automergeDoc.save(),
        'group_context_parts': parts.toJsonString(),
        'sequence_number': doc.sequenceNumber,
      },
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  }

  Future<void> updateAccount(ExternalAccount account) async {
    await _update(
      contactsTable,
      {'name': account.name},
      where: 'actor_id = ?',
      whereArgs: [account.actorId, AccountKind.user.name],
    );
  }

  Future<void> deleteDocument(String id) async {
    await _delete(documentsTable, where: "id = ?", whereArgs: [id]);
  }
}
