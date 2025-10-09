import 'package:flutter/services.dart';

class SQLAccount {
  final String actorId;
  final Uint8List publicKey;
  final String name;
  final Uint8List? image;

  SQLAccount({
    required this.actorId,
    required this.publicKey,
    required this.name,
    this.image,
  });

  Map<String, Object?> toJson() {
    return {
      'actor_id': actorId,
      'public_key': publicKey,
      'name': name,
      'image': image,
    };
  }

  static SQLAccount fromJson(Map<String, Object?> json) {
    return SQLAccount(
      actorId: json['actor_id'] as String,
      publicKey: json['public_key'] as Uint8List,
      name: json['name'] as String,
      image: json['image'] as Uint8List?,
    );
  }
}
