import 'dart:typed_data';

class SQLSpk {
  final String contactId;
  final Uint8List? privateKey;
  final Uint8List publicKey;

  SQLSpk({
    required this.contactId,
    this.privateKey,
    required this.publicKey,
  });

  factory SQLSpk.fromJson(Map<String, Object?> json) {
    return SQLSpk(
      contactId: json['contact_id'] as String,
      privateKey: json['private_key'] as Uint8List?,
      publicKey: json['public_key'] as Uint8List,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contact_id': contactId,
      'private_key': privateKey,
      'public_key': publicKey,
    };
  }
}
