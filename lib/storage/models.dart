import 'package:flutter/cupertino.dart';
import 'package:hex/hex.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/utils/group_context_factory.dart';
import 'package:veil/utils/secret_factory.dart';

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
      rawPublicKey: List<int>.from(json['publicKey']),
    );
  }
}

class DocumentMember {
  final ExternalAccount account;
  final int role;
  final String roleName;

  DocumentMember.fromJson(Map<String, dynamic> json)
    : account = ExternalAccount.fromJson(json['account']),
      role = json['role'],
      roleName = json['role_name'];

  toJson() => Map<String, dynamic>.from({
    'account': account.toJson(),
    'role': int,
    'role_name': roleName,
  });

  DocumentMember({
    required this.account,
    required this.role,
    required this.roleName,
  });
}

class DocumentMemberRole {}

class Document {
  final String id;
  BAutoCommit automergeDoc;
  DateTime createdAt;
  GroupContextParts groupContextParts;
  int sequenceNumber;
  bool localOnly;

  Key get key => ValueKey(id);

  Document({
    required this.id,
    required this.automergeDoc,
    required this.createdAt,
    required this.groupContextParts,
    this.sequenceNumber = 0,
    this.localOnly = false,
  });

  void setDocument(BAutoCommit doc) {
    automergeDoc = doc;
  }

  void incrementSequenceNumber() {
    sequenceNumber++;
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
    final (publicKey, secretKey) = SecretManager.intance.generateKeypair();
    return Keypair(rawPublicKey: publicKey, rawPrivateKey: secretKey);
  }
}

class Account {
  String name;
  final String actorId;
  final Keypair keypair;

  Account({required this.name, required this.actorId, required this.keypair});
  factory Account.withName(String name) {
    final keypair = Keypair.generate();

    return Account(
      name: name,
      actorId: hashPublicKey(pk: keypair.rawPublicKey),
      keypair: keypair,
    );
  }

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
