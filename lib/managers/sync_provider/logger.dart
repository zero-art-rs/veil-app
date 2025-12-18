import 'package:talker_flutter/talker_flutter.dart';

class SyncModelCentrifugoTalkerLog extends TalkerLog {
  SyncModelCentrifugoTalkerLog(
    super.message, {
    super.logLevel = LogLevel.debug,
    super.stackTrace,
  });

  @override
  String get title => 'Sync model centrifugo';
}

class SyncModelProcessTalkerLog extends TalkerLog {
  SyncModelProcessTalkerLog(
    super.message, {
    super.logLevel = LogLevel.debug,
    super.stackTrace,
  });

  @override
  String get title => 'Sync model process';
}

class SyncModelWriteTalkerLog extends TalkerLog {
  SyncModelWriteTalkerLog(
    super.message, {
    super.stackTrace,
    super.logLevel = LogLevel.debug,
  });

  @override
  String get title => 'Sync model write';
}

class SyncModelStateTalkerLog extends TalkerLog {
  SyncModelStateTalkerLog(
    super.message, {
    super.logLevel = LogLevel.debug,
    super.stackTrace,
  });

  @override
  String get title => 'Sync model state';
}

class SyncModelTalkerLog extends TalkerLog {
  SyncModelTalkerLog(
    super.message, {
    super.logLevel = LogLevel.debug,
    super.stackTrace,
  });

  @override
  String get title => 'Sync model';
}

class SyncModelEventTalkerLog extends TalkerLog {
  SyncModelEventTalkerLog(
    super.message, {
    super.logLevel = LogLevel.debug,
    super.stackTrace,
  });

  @override
  String get title => 'Sync model event';
}

extension SyncModelTalker on Talker {
  void processLog(
    String message, {
    LogLevel level = LogLevel.info,
    StackTrace? stackTrace,
  }) {
    logCustom(
      SyncModelProcessTalkerLog(
        message,
        stackTrace: stackTrace,
        logLevel: level,
      ),
    );
  }

  void writeLog(
    String message, {
    LogLevel level = LogLevel.info,
    StackTrace? stackTrace,
  }) {
    logCustom(
      SyncModelWriteTalkerLog(message, logLevel: level, stackTrace: stackTrace),
    );
  }

  void stateLog(
    String message, {
    LogLevel level = LogLevel.info,
    StackTrace? stackTrace,
  }) {
    logCustom(
      SyncModelStateTalkerLog(message, logLevel: level, stackTrace: stackTrace),
    );
  }

  void centrifugoLog(
    String message, {
    LogLevel level = LogLevel.info,
    StackTrace? stackTrace,
  }) {
    logCustom(
      SyncModelCentrifugoTalkerLog(
        message,
        logLevel: level,
        stackTrace: stackTrace,
      ),
    );
  }

  void modelLog(
    String message, {
    LogLevel level = LogLevel.info,
    StackTrace? stackTrace,
  }) {
    logCustom(
      SyncModelTalkerLog(message, logLevel: level, stackTrace: stackTrace),
    );
  }

  void eventLog(
    String message, {
    LogLevel level = LogLevel.info,
    StackTrace? stackTrace,
  }) {
    logCustom(
      SyncModelEventTalkerLog(message, logLevel: level, stackTrace: stackTrace),
    );
  }
}
