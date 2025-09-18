import 'dart:typed_data';

class SQLDocument {
  String id;
  String title;
  Uint8List content;
  DateTime createdAt;
  DateTime updatedAt;
  String groupContextParts;

  SQLDocument({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.groupContextParts,
  });

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'group_context_parts': groupContextParts,
    };
  }
}

class SQLDocumentMember {
  String actorId;
  String documentId;
  int role;
  DateTime createdAt;
  DateTime updatedAt;

  SQLDocumentMember({
    required this.actorId,
    required this.documentId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toJson() {
    return {
      'actor_id': actorId,
      'document_id': documentId,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SQLDocumentMember.fromJson(Map<String, Object?> json) {
    return SQLDocumentMember(
      actorId: json['actor_id'] as String,
      documentId: json['document_id'] as String,
      role: json['role'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
