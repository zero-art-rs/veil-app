import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:hex/hex.dart';
import 'package:uuid/v4.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:zk_notion_app/src/rust/api/group_context.dart';

class ExternalAccount {
  final String actorId;
  final String name;
  final List<int> rawPublicKey;

  String get publicKey => HEX.encode(rawPublicKey);

  ExternalAccount({
    required this.actorId,
    required this.name,
    required this.rawPublicKey,
  });

  toJson() => Map<String, dynamic>.from({
    'actorId': actorId,
    'name': name,
    'publicKey': rawPublicKey,
  });

  factory ExternalAccount.fromAccount(Account account) => ExternalAccount(
    actorId: account.actorId,
    name: account.name,
    rawPublicKey: account.keypair.rawPublicKey,
  );

  factory ExternalAccount.fromJson(Map<String, dynamic> json) {
    return ExternalAccount(
      actorId: json['actorId'],
      name: json['name'],
      rawPublicKey: json['publicKey'],
    );
  }
}

class DocumentMember {
  final ExternalAccount account;
  final bool isOwner;

  DocumentMember.fromJson(Map<String, dynamic> json)
    : account = ExternalAccount.fromJson(json['account']),
      isOwner = json['isOwner'];

  toJson() => Map<String, dynamic>.from({
    'account': account.toJson(),
    'isOwner': isOwner,
  });

  DocumentMember({required this.account, required this.isOwner});
}

class Document {
  final String id;
  final String title;
  final BAutoCommit automergeDoc;
  final List<DocumentMember> members;
  DateTime createdAt;
  DateTime updatedAt;
  Key get key => ValueKey(id + title);

  Document({
    required this.id,
    required this.title,
    required this.automergeDoc,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
  });

  toJson() => Map<String, dynamic>.from({
    'id': id,
    'title': title,
    'content': automergeDoc.save().toList(),
    'members': members,
  });

  String ownerName() => members.firstWhere((e) => e.isOwner).account.name;

  factory Document.withGeneratedId({
    required String title,
    required BAutoCommit content,
    required DocumentMember owner,
  }) => Document(
    id: UuidV4().generate(),
    title: title,
    automergeDoc: content,
    members: [owner],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      title: json['title'],
      automergeDoc: BAutoCommit.fromBytes(
        bytes: Uint8List.fromList(List<int>.from(json['content'])),
      ),
      members: (json['members'])
          .map<DocumentMember>((e) => DocumentMember.fromJson(e))
          .toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class Keypair {
  final List<int> rawPublicKey;
  final List<int> rawPrivateKey;

  String get publicKeyHex => HEX.encode(rawPublicKey);
  String get privateKeyHex => HEX.encode(rawPrivateKey);

  Keypair({required this.rawPublicKey, required this.rawPrivateKey});

  factory Keypair.fromJson(Map<String, dynamic> json) {
    return Keypair(
      rawPublicKey: List<int>.from(json['rawPublicKey']),
      rawPrivateKey: List<int>.from(json['rawPrivateKey']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'rawPublicKey': rawPublicKey, 'rawPrivateKey': rawPrivateKey};
  }

  static Keypair generate() {
    final random = Random.secure();

    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );

    final (publicKey, secretKey) = BSecretsFactory(
      seed: U8Array32(seed),
    ).generateSecretWithPublicKey();

    return Keypair(rawPublicKey: publicKey, rawPrivateKey: secretKey);
  }
}

class Account {
  final String name;
  final String actorId;
  final Keypair keypair;

  Account({required this.name, required this.actorId, required this.keypair});
  factory Account.withName(String name, {bool isCurrentUser = true}) => Account(
    name: name,
    actorId: generateActorId(),
    keypair: Keypair.generate(),
  );

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      name: json['name'],
      actorId: json['actorId'],
      keypair: Keypair.fromJson(json['keypair']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'actorId': actorId, 'keypair': keypair.toJson()};
  }
}
