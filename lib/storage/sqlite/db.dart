import 'dart:convert';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/v4.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/contacts_manager.dart';
import 'package:veil/managers/sharing/spk_manager.dart';
import 'package:veil/managers/sharing/spk_provider.dart';
import 'package:veil/managers/sync_provider/local_crdt_storage.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/storage/models/document_state.dart';
import 'package:veil/storage/models/external_account.dart';
import 'package:veil/storage/sqlite/models/account.dart';
import 'package:veil/storage/sqlite/consts.dart';
import 'package:veil/storage/sqlite/models/crdt_change.dart';
import 'package:veil/storage/sqlite/models/document.dart';
import 'package:veil/storage/sqlite/models/spk.dart';
import 'package:veil/storage/sqlite/schemes.dart';
import 'package:veil/utils/group_context_factory.dart';
import 'package:veil/utils/platform.dart';

const _dbName = 'veil.db';

class DB extends LocalCrdtStorage {
  static final instance = DB._();
  late Database _connection;
  Transaction? _tx;

  DB._();

  Future<void> openTest({required String inMemoryPath}) async {
    databaseFactory = databaseFactoryFfi;

    _connection = await openDatabase(
      '$inMemoryPath/$_dbName',
      version: 1,
      readOnly: false,
      onConfigure: (db) {
        db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute(createContactsTable);
        await db.execute(createSpksTable);
        await db.execute(createDocumentsTable);
        await db.execute(createCrdtChangesTable);

        final ownerAccount = SQLAccount(
          actorId: 'owner',
          publicKey: Uint8List(0),
          name: 'owner',
        );

        await db.insert(accountsTable, ownerAccount.toJson());
      },
    );
  }

  Future<void> open() async {
    if (PlatformUtils.isWindows || PlatformUtils.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationSupportDirectory();
    logger.info('Database path: ${dir.path}/$_dbName');

    _connection = await openDatabase(
      '${dir.path}/$_dbName',
      version: 1,
      readOnly: false,
      onConfigure: (db) {
        db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute(createContactsTable);
        await db.execute(createSpksTable);
        await db.execute(createDocumentsTable);
        await db.execute(createCrdtChangesTable);

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

  Future<Contact> insertContact(SpkShareData spk) async {
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
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db._delete(
        spksTable,
        where: 'contact_id = ?',
        whereArgs: [spk.account.actorId],
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

  Future<List<DocumentState>> getDocumentStateList() async {
    final rawDocuments = await _connection.rawQuery(
      "SELECT * FROM documents ORDER BY created_at ASC",
    );

    final sqlDocuments = rawDocuments
        .map((e) => SQLDocumentState.fromJson(e))
        .toList();

    final documents = sqlDocuments
        .map(
          (doc) => DocumentState(
            id: doc.id,
            crdt: BAutoCommit.fromBytes(bytes: doc.content),
            createdAt: doc.createdAt,
            groupContextParts: GroupContextParts.fromJsonString(
              doc.groupContextParts,
            ),
            sequenceNumber: doc.sequenceNumber,
            isLocal: doc.isLocal == 1,
          ),
        )
        .toList();

    return documents;
  }

  Future<DocumentState?> getDocumentById(String id) async {
    final rawDocument = await _connection.query(
      documentsTable,
      where: 'id = ?',
      whereArgs: [id],
      orderBy: 'created_at ASC',
    );

    if (rawDocument.isEmpty) return null;

    final doc = SQLDocumentState.fromJson(rawDocument.first);

    return DocumentState(
      id: doc.id,
      crdt: BAutoCommit.fromBytes(bytes: doc.content),
      createdAt: doc.createdAt,
      groupContextParts: GroupContextParts.fromJsonString(
        doc.groupContextParts,
      ),
      isLocal: doc.isLocal == 1,
      sequenceNumber: doc.sequenceNumber,
    );
  }

  Future<void> makeDocumentLocalOnly({required String id}) async {
    await _update(
      documentsTable,
      {'local_only': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertDocumentState({
    required DocumentState documentState,
  }) async {
    final sqlDoc = SQLDocumentState(
      id: documentState.id,
      content: documentState.crdt.save(),
      createdAt: documentState.createdAt,
      groupContextParts: documentState.groupContextParts.toJsonString(),
      sequenceNumber: documentState.sequenceNumber,
      isLocal: documentState.isLocal ? 1 : 0,
    );

    await _insert(
      documentsTable,
      sqlDoc.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateDocumentState({
    required DocumentState documentState,
    required GroupContextParts groupContextParts,
  }) async {
    await _update(
      documentsTable,
      {
        'content': documentState.crdt.save(),
        'group_context_parts': groupContextParts.toJsonString(),
        'sequence_number': documentState.sequenceNumber,
      },
      where: 'id = ?',
      whereArgs: [documentState.id],
    );
  }

  Future<void> updateCrdtDocumentState({
    required DocumentState documentState,
  }) async {
    await _update(
      documentsTable,
      {
        'content': documentState.crdt.save(),
        'sequence_number': documentState.sequenceNumber,
      },
      where: 'id = ?',
      whereArgs: [documentState.id],
    );
  }

  Future<void> updateGroupContextDocumentState({
    required String id,
    required GroupContextParts parts,
  }) async {
    await _update(
      documentsTable,
      {'group_context_parts': parts.toJsonString()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> insertLocalCrdtChange({
    required String documentId,
    required Uint8List data,
  }) async {
    await _insert(
      crdtChangesTable,
      CrdtChange.fromContent(documentId: documentId, content: data).toJson(),
    );
  }

  @override
  Future<List<CrdtChange>> getLocalCrdtChanges({
    required String documentId,
  }) async {
    final rawChanges = await _query(
      crdtChangesTable,
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'create_at ASC',
    );

    return rawChanges.map((e) => CrdtChange.fromMap(e)).toList();
  }

  @override
  Future<void> deleteLocalCrdtChanges({
    required String documentId,
    required List<String> ids,
  }) async {
    final idsPlaceholders = List.filled(ids.length, '?').join(', ');

    await _delete(
      crdtChangesTable,
      where: 'document_id = ? AND id IN ($idsPlaceholders)',
      whereArgs: [documentId, ...ids],
    );
  }

  Future<void> deleteDocumentState(String id) async {
    await _delete(documentsTable, where: "id = ?", whereArgs: [id]);
  }
}
