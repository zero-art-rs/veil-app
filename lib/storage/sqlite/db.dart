import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/v4.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:zk_notion_app/storage/models.dart';
import 'package:zk_notion_app/storage/sqlite/models/account.dart';
import 'package:zk_notion_app/storage/sqlite/consts.dart';
import 'package:zk_notion_app/storage/sqlite/models/document.dart';
import 'package:zk_notion_app/storage/sqlite/schemes.dart';

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
        // Tables
        await db.execute(createAccountTable);
        await db.execute(createContactsSpksTable);
        await db.execute(createDocumentsTable);
        await db.execute(createDocumentMembersTable);
        await db.execute(createEpochsTable);
        await db.execute(createGroupsTable);

        // Triggers
        await db.execute(accountCleanupTrigger);
        await db.execute(removeSpksOnFamiliarTrigger);
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
      accountsTable,
      sqlAccount.toJson(),
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<void> deleteContact({required String actorId}) async {
    final members = await _query(
      documentMembersTable,
      where: 'actor_id = ?',
      whereArgs: [actorId],
    );

    if (members.isEmpty) {
      await _delete(accountsTable, where: 'actor_id = ?', whereArgs: [actorId]);
    } else {
      await _update(
        accountsTable,
        {'kind': AccountKind.familiar.name},
        where: 'actor_id = ?',
        whereArgs: [actorId],
      );
    }
  }

  Future<List<ExternalAccount>> getContactList() async {
    final rawAccounts = await _query(
      accountsTable,
      where: 'kind = ?',
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
    final rows = await _connection.rawQuery('''
    SELECT 
      d.id              AS document_id,
      d.title           AS document_title,
      d.content         AS document_content,
      d.created_at      AS document_created_at,
      d.updated_at      AS document_updated_at,

      m.actor_id        AS member_actor_id,
      m.role            AS member_role,
      m.created_at      AS member_created_at,
      m.updated_at      AS member_updated_at,

      a.name            AS account_name,
      a.public_key      AS account_public_key,
      a.image           AS account_image,
      a.kind            AS account_kind
    FROM $documentsTable d
    LEFT JOIN $documentMembersTable m ON d.id = m.document_id
    LEFT JOIN $accountsTable a ON m.actor_id = a.actor_id
    ORDER BY d.created_at DESC
  ''');

    final Map<String, Document> docs = {};

    for (final row in rows) {
      final docId = row['document_id'] as String;

      docs.putIfAbsent(
        docId,
        () => Document(
          id: docId,
          title: row['document_title'] as String,
          automergeDoc: BAutoCommit.fromBytes(
            bytes: row['document_content'] as Uint8List,
          ),
          members: [],
          createdAt: DateTime.parse(row['document_created_at'] as String),
          updatedAt: DateTime.parse(row['document_updated_at'] as String),
        ),
      );

      if (row['member_actor_id'] != null) {
        final account = ExternalAccount(
          actorId: row['member_actor_id'] as String,
          name: row['account_name'] as String,
          rawPublicKey: row['account_public_key'] as List<int>,
        );

        docs[docId]!.members.add(
          DocumentMember(
            account: account,
            isOwner: (row['member_role'] as int) == ownerRole,
          ),
        );
      }
    }

    return docs.values.toList();
  }

  Future<void> insertDocument({required Document document}) async {
    final sqlDoc = SQLDocument(
      id: document.id,
      title: document.title,
      content: document.automergeDoc.save(),
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
    );

    await _insert(documentsTable, sqlDoc.toJson());

    for (final member in document.members) {
      await insertDocumentMember(documentId: document.id, member: member);
    }

    for (final member in document.members) {
      await insertAccount(
        account: member.account,
        kind: AccountKind.familiar,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<Document> insertNewDocument({
    required String title,
    required ExternalAccount owner,
  }) async {
    final now = DateTime.now();
    final docId = const UuidV4().generate();
    final content = BAutoCommit();

    final sqlDoc = SQLDocument(
      id: docId,
      title: title,
      content: content.save(),
      createdAt: now,
      updatedAt: now,
    );

    await _insert(documentsTable, sqlDoc.toJson());
    await insertDocumentMember(
      documentId: docId,
      member: DocumentMember(account: owner, isOwner: true),
    );

    return Document(
      id: docId,
      title: title,
      automergeDoc: content,
      members: [DocumentMember(account: owner, isOwner: true)],
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> insertDocumentMember({
    required String documentId,
    required DocumentMember member,
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort,
  }) async {
    final now = DateTime.now();

    final sqlDocMember = SQLDocumentMember(
      actorId: member.account.actorId,
      documentId: documentId,
      role: member.isOwner ? ownerRole : editorRole,
      createdAt: now,
      updatedAt: now,
    );

    await _insert(
      documentMembersTable,
      sqlDocMember.toJson(),
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<void> insertAccount({
    required ExternalAccount account,
    required AccountKind kind,
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort,
  }) async {
    final sqlAccount = SQLAccount(
      actorId: account.actorId,
      publicKey: Uint8List.fromList(account.rawPublicKey),
      name: account.name,
      kind: kind.name,
    );

    await _insert(
      accountsTable,
      sqlAccount.toJson(),
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<void> setupAccountIfNeeded(ExternalAccount account) async {
    await insertAccount(
      account: account,
      kind: AccountKind.user,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> updateAccount(ExternalAccount account) async {
    await _update(
      accountsTable,
      {'name': account.name},
      where: 'actor_id = ? AND kind = ?',
      whereArgs: [account.actorId, AccountKind.user.name],
    );
  }

  Future<void> deleteMember(String id) async {
    await _delete(documentMembersTable, where: "actor_id = ?", whereArgs: [id]);
  }

  Future<Document> updateDocumentTitle(Document doc) async {
    await _update(
      documentsTable,
      {'title': doc.title, 'updated_at': doc.updatedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [doc.id],
    );

    return doc;
  }

  Future<void> updateDocumentContent(Document doc) async {
    await _update(
      documentsTable,
      {
        'content': doc.automergeDoc.save(),
        'updated_at': doc.updatedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  }

  Future<void> deleteDocument(String id) async {
    await _delete(documentsTable, where: "id = ?", whereArgs: [id]);
  }
}
