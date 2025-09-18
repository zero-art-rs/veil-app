import 'dart:typed_data';

class SQLGroupContext {
  final String groupId;
  final Uint8List leafSecret;
  final Uint8List art;
  final Uint8List stageKey;
  final int epoch;
  final Uint8List groupInfo;

  SQLGroupContext({
    required this.groupId,
    required this.leafSecret,
    required this.art,
    required this.stageKey,
    required this.epoch,
    required this.groupInfo,
  });

  Map<String, dynamic> toJson() => {
    'document_id': groupId,
    'leaf_secret': leafSecret,
    'art': art,
    'stage_key': stageKey,
    'epoch': epoch,
    'group_info': groupInfo,
  };

  factory SQLGroupContext.fromJson(Map<String, dynamic> json) =>
      SQLGroupContext(
        groupId: json['document_id'] as String,
        leafSecret: json['leaf_secret'] as Uint8List,
        art: json['art'] as Uint8List,
        stageKey: json['stage_key'] as Uint8List,
        epoch: json['epoch'] as int,
        groupInfo: json['group_info'] as Uint8List,
      );
}
