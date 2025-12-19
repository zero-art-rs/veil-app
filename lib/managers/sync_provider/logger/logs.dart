import 'package:talker_flutter/talker_flutter.dart';

class SyncModelCentrifugoTalkerLog extends TalkerLog {
  final String id;

  SyncModelCentrifugoTalkerLog(
    super.message, {
    required this.id,
    super.logLevel = LogLevel.debug,
    super.stackTrace,
  });

  @override
  String get title => '$id Sync model centrifugo';
}

class SyncModelProcessTalkerLog extends TalkerLog {
  final String id;

  SyncModelProcessTalkerLog(
    super.message, {
    required this.id,
    super.logLevel = LogLevel.debug,
    super.stackTrace,
  });

  @override
  String get title => '$id Sync model process';
}

class SyncModelWriteTalkerLog extends TalkerLog {
  final String id;

  SyncModelWriteTalkerLog(
    super.message, {
    required this.id,
    super.stackTrace,
    super.logLevel = LogLevel.debug,
  });

  @override
  String get title => '$id Sync model write';
}

class SyncModelStateTalkerLog extends TalkerLog {
  final String id;

  SyncModelStateTalkerLog(
    super.message, {
    required this.id,
    super.logLevel = LogLevel.debug,
    super.stackTrace,
  });

  @override
  String get title => '$id Sync model state';
}

class SyncModelTalkerLog extends TalkerLog {
  final String id;

  SyncModelTalkerLog(
    super.message, {
    required this.id,
    super.logLevel = LogLevel.debug,
    super.stackTrace,
  });

  @override
  String get title => '$id Sync model';
}

class SyncModelEventTalkerLog extends TalkerLog {
  final String id;

  SyncModelEventTalkerLog(
    super.message, {
    required this.id,
    super.logLevel = LogLevel.debug,
    super.stackTrace,
  });

  @override
  String get title => '$id Sync model event';
}
