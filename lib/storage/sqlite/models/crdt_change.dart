import 'package:flutter/foundation.dart';
import 'package:uuid/v4.dart';

class CrdtChange {
  final String id;
  final String documentId;
  final Uint8List content;
  final DateTime createdAt;

  CrdtChange({
    required this.id,
    required this.documentId,
    required this.content,
    required this.createdAt,
  });

  factory CrdtChange.fromContent({
    required String documentId,
    required Uint8List content,
  }) {
    return CrdtChange(
      id: UuidV4().generate(),
      documentId: documentId,
      content: content,
      createdAt: DateTime.now().toUtc(),
    );
  }

  factory CrdtChange.fromMap(Map<String, dynamic> map) {
    return CrdtChange(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      content: map['content'],
      createdAt: DateTime.parse(map['create_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'document_id': documentId,
      'content': content,
      'create_at': createdAt.toIso8601String(),
    };
  }
}
