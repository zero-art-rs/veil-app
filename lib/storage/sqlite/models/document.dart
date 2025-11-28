import 'dart:typed_data';

class SQLDocumentState {
  String id;
  Uint8List content;
  DateTime createdAt;
  String groupContextParts;
  int sequenceNumber;
  int isLocal;

  SQLDocumentState({
    required this.id,
    required this.content,
    required this.groupContextParts,
    required this.sequenceNumber,
    required this.createdAt,
    this.isLocal = 0,
  });

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'group_context_parts': groupContextParts,
      'sequence_number': sequenceNumber,
      'is_local': isLocal,
    };
  }

  factory SQLDocumentState.fromJson(Map<String, Object?> json) {
    return SQLDocumentState(
      id: json['id'] as String,
      content: json['content'] as Uint8List,
      createdAt: DateTime.parse(json['created_at'] as String),
      groupContextParts: json['group_context_parts'] as String,
      sequenceNumber: json['sequence_number'] as int,
      isLocal: json['is_local'] as int,
    );
  }
}
