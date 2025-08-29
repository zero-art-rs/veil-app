import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/v4.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'dart:convert';

class Document {
  final String id;
  final String title;
  final String owner;
  final BAutoCommit content;

  Document({
    required this.id,
    required this.title,
    required this.content,
    required this.owner,
  });

  toJson() => Map<String, dynamic>.from({
    'id': id,
    'title': title,
    'content': content.save().toList(),
    'owner': owner,
  });

  factory Document.withGeneratedId({
    required String title,
    required BAutoCommit content,
    required String owner,
  }) => Document(
    id: UuidV4().generate(),
    title: title,
    content: content,
    owner: owner,
  );

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      title: json['title'],
      content: BAutoCommit.fromBytes(
        bytes: Uint8List.fromList(List<int>.from(json['content'])),
      ),
      owner: json['owner'],
    );
  }
}

class Account {
  final String name;
  final String actorId;

  Account({required this.name, required this.actorId});
  factory Account.withId(String name) =>
      Account(name: name, actorId: generateActorId());

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(name: json['name'], actorId: json['actorId']);
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'actorId': actorId};
  }
}

class AppStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static final AppStorage shared = AppStorage();

  Future<Account?> getAccount() async {
    final account = await _storage.read(key: 'account');

    if (account == null) {
      return null;
    }

    return Account.fromJson(jsonDecode(account));
  }

  Future<void> setAccount(Account account) async {
    await _storage.write(key: 'account', value: jsonEncode(account.toJson()));
  }

  Future<Document> createDocument({
    required String title,
    required String owner,
  }) async {
    final autocommit = BAutoCommit();

    final document = Document.withGeneratedId(
      title: title,
      owner: owner,
      content: autocommit,
    );

    await _storage.write(
      key: document.id,
      value: jsonEncode(document.toJson()),
    );

    return document;
  }

  Future<List<Document>> getDocuments() async {
    final rawDocuments = await _storage.readAll();

    final documents = rawDocuments.entries
        .where((entry) => entry.key != 'account')
        .map((entry) {
          return Document.fromJson(jsonDecode(entry.value));
        })
        .toList();

    return documents;
  }

  Future<void> updateDocument(Document document) async {
    await _storage.write(
      key: document.id,
      value: jsonEncode(document.toJson()),
    );
  }

  removeDocument(String id) async {
    await _storage.delete(key: id);
  }
}
