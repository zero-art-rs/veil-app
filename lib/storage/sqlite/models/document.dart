import 'dart:typed_data';

class SQLDocument {
  String id;
  String title;
  Uint8List content;
  DateTime createdAt;
  String groupContextParts;

  SQLDocument({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.groupContextParts,
  });

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'group_context_parts': groupContextParts,
    };
  }

  factory SQLDocument.fromJson(Map<String, Object?> json) {
    return SQLDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as Uint8List,
      createdAt: DateTime.parse(json['created_at'] as String),
      groupContextParts: json['group_context_parts'] as String,
    );
  }
}
