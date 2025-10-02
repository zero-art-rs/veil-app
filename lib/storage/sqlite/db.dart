import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:veil/managers/contacts_manager.dart';
import 'package:veil/managers/sharing/spk_manager.dart';
import 'package:veil/managers/sharing/spk_provider.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/models/account.dart';
import 'package:veil/storage/sqlite/consts.dart';
import 'package:veil/storage/sqlite/models/document.dart';
import 'package:veil/storage/sqlite/models/spk.dart';
import 'package:veil/storage/sqlite/schemes.dart';
import 'package:veil/utils/group_context_factory.dart';

const _dbName = 'veil.db';

class DB {
  static final instance = DB();
  late Database _connection;
  Transaction? _tx;

  DB();

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
        await db.execute(createSpksTable);
        await db.execute(createDocumentsTable);

        final ownerAccount = SQLAccount(
          actorId: 'owner',
          publicKey: Uint8List(0),
          name: 'owner',
        );

        await db.insert(accountsTable, ownerAccount.toJson());
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
      await db._delete(
        accountsTable,
        where: 'actor_id != ?',
        whereArgs: ['owner'],
      );
      await db._delete(spksTable);
      await db._delete(documentsTable);
    });
  }

  Future<void> insertOwnedSpks(List<SpkSendModel> spks) async {
    final sqlspks = spks.map(
      (e) => SQLSpk(
        privateKey: Uint8List.fromList(e.privateKey),
        publicKey: Uint8List.fromList(e.publicKey),
        contactId: 'owner',
      ),
    );

    await transaction((db) async {
      for (final spk in sqlspks) {
        await db._insert(spksTable, spk.toMap());
      }
    });
  }

  Future<List<int>?> getOwnSpkSecret(List<int> publicKey) async {
    final rawOwnSpk = await _query(
      spksTable,
      where: 'public_key = ? AND contact_id = ?',
      whereArgs: [base64Encode(publicKey), 'owner'],
    );

    // logger.i('rawOwnSpk: ${base64Encode(rawOwnSpk)}');

    if (rawOwnSpk.firstOrNull == null) {
      return null;
    }

    final sqlSpk = SQLSpk.fromJson(rawOwnSpk.first);
    return sqlSpk.privateKey;
  }

  Future<void> removeSpk(List<int> publicKey) async {
    await _delete(
      spksTable,
      where: 'public_key = ?',
      whereArgs: [base64Encode(publicKey)],
    );
  }

  Future<Contact> insertContact(
    SpkShareData spk, {
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.rollback,
  }) async {
    final sqlAccount = SQLAccount(
      actorId: spk.account.actorId,
      publicKey: Uint8List.fromList(spk.account.rawPublicKey),
      name: spk.account.name,
    );

    final sqlspks = spk.spks.map(
      (e) => SQLSpk(
        publicKey: Uint8List.fromList(e.publicKey),
        contactId: spk.account.actorId,
      ),
    );

    await transaction((db) async {
      await db._insert(
        accountsTable,
        sqlAccount.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      for (final spk in sqlspks) {
        await db._insert(spksTable, spk.toMap());
      }
    });

    return Contact(
      account: spk.account,
      spks: spk.spks.map((e) => e.publicKey).toList(),
    );
  }

  Future<Contact> getContact(String actorId) async {
    final rawAccount = await _query(
      accountsTable,
      where: 'actor_id != ? AND actor_id = ?',
      whereArgs: ['owner', actorId],
    );

    if (rawAccount.firstOrNull == null) {
      throw Exception('Contact not found');
    }

    final sqlAccount = SQLAccount.fromJson(rawAccount.first);
    final externalAccount = ExternalAccount(
      actorId: sqlAccount.actorId,
      rawPublicKey: sqlAccount.publicKey,
      name: sqlAccount.name,
    );

    final rawSpks = await _query(
      spksTable,
      where: 'contact_id = ?',
      whereArgs: [externalAccount.actorId],
    );

    final sqlSpks = rawSpks.map((e) => SQLSpk.fromJson(e)).toList();

    return Contact(
      account: externalAccount,
      spks: sqlSpks.map((e) => e.publicKey).toList(),
    );
  }

  Future<void> deleteContact({required String actorId}) async {
    await _delete(accountsTable, where: 'actor_id = ?', whereArgs: [actorId]);
  }

  Future<List<Contact>> getContactList() async {
    final rawAccounts = await _query(
      accountsTable,
      where: 'actor_id != ?',
      whereArgs: ['owner'],
    );

    final sqlAccounts = rawAccounts.map((e) => SQLAccount.fromJson(e)).toList();

    final externalAccounts = sqlAccounts
        .map(
          (e) => ExternalAccount(
            actorId: e.actorId,
            rawPublicKey: e.publicKey,
            name: e.name,
          ),
        )
        .toList();

    final List<Contact> contacts = [];
    for (final account in externalAccounts) {
      final rawSpks = await _query(
        spksTable,
        where: 'contact_id = ?',
        whereArgs: [account.actorId],
      );

      final sqlSpks = rawSpks.map((e) => SQLSpk.fromJson(e)).toList();

      contacts.add(
        Contact(
          account: account,
          spks: sqlSpks.map((e) => e.publicKey).toList(),
        ),
      );
    }

    return contacts;
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

      content: document.automergeDoc.save(),
      createdAt: document.createdAt,
      groupContextParts: document.groupContextParts.toJsonString(),
      sequenceNumber: document.sequenceNumber,
    );

    await _insert(documentsTable, sqlDoc.toJson());
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

  Future<void> deleteDocument(String id) async {
    await _delete(documentsTable, where: "id = ?", whereArgs: [id]);
  }
}
