import 'dart:convert';
import 'dart:typed_data';

class SQLSpk {
  final String contactId;
  final Uint8List? privateKey;
  final Uint8List publicKey;

  SQLSpk({required this.contactId, this.privateKey, required this.publicKey});

  factory SQLSpk.fromJson(Map<String, Object?> json) {
    final privateKey = json['private_key'] as String?;

    return SQLSpk(
      contactId: json['contact_id'] as String,
      privateKey: privateKey == null ? null : base64Decode(privateKey),
      publicKey: base64Decode(json['public_key'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contact_id': contactId,
      'private_key': privateKey == null ? null : base64Encode(privateKey!),
      'public_key': base64Encode(publicKey),
    };
  }
}
