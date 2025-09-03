import 'dart:math';
import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:uuid/v4.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';

class ExternalAccount {
  final String actorId;
  final String name;
  final String publicKey;

  ExternalAccount({
    required this.actorId,
    required this.name,
    required this.publicKey,
  });

  toJson() => Map<String, dynamic>.from({
    'actorId': actorId,
    'name': name,
    'publicKey': publicKey,
  });

  factory ExternalAccount.fromAccount(Account account) => ExternalAccount(
    actorId: account.actorId,
    name: account.name,
    publicKey: account.keypair.publicKey,
  );

  factory ExternalAccount.fromJson(Map<String, dynamic> json) {
    return ExternalAccount(
      actorId: json['actorId'],
      name: json['name'],
      publicKey: json['publicKey'],
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
  final BAutoCommit content;
  final List<DocumentMember> members;

  Document({
    required this.id,
    required this.title,
    required this.content,
    required this.members,
  });

  toJson() => Map<String, dynamic>.from({
    'id': id,
    'title': title,
    'content': content.save().toList(),
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
    content: content,
    members: [owner],
  );

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      title: json['title'],
      content: BAutoCommit.fromBytes(
        bytes: Uint8List.fromList(List<int>.from(json['content'])),
      ),
      members: (json['members'])
          .map<DocumentMember>((e) => DocumentMember.fromJson(e))
          .toList(),
    );
  }
}

class Keypair {
  final String publicKey;
  final String privateKey;

  Keypair({required this.publicKey, required this.privateKey});

  factory Keypair.fromJson(Map<String, dynamic> json) {
    return Keypair(
      publicKey: json['publicKey'],
      privateKey: json['privateKey'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'publicKey': publicKey, 'privateKey': privateKey};
  }

  static Keypair generate() {
    final random = Random.secure();
    final publicKey = List<int>.generate(32, (_) => random.nextInt(256));
    final privateKey = List<int>.generate(32, (_) => random.nextInt(256));

    return Keypair(
      publicKey: HEX.encode(publicKey),
      privateKey: HEX.encode(privateKey),
    );
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
