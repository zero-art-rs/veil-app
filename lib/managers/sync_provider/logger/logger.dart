import 'package:talker_flutter/talker_flutter.dart';
import 'package:veil/managers/sync_provider/logger/logs.dart';

class SyncModelLogger {
  final Talker logger;
  final String id;

  SyncModelLogger(this.logger, this.id);

  void writeLog(
    String message, {
    LogLevel level = LogLevel.info,
    StackTrace? stackTrace,
  }) {
    logger.logCustom(
      SyncModelWriteTalkerLog(
        message,
        id: id,
        logLevel: level,
        stackTrace: stackTrace,
      ),
    );
  }

  void stateLog(
    String message, {
    LogLevel level = LogLevel.info,
    StackTrace? stackTrace,
  }) {
    logger.logCustom(
      SyncModelStateTalkerLog(
        message,
        id: id,
        logLevel: level,
        stackTrace: stackTrace,
      ),
    );
  }

  void centrifugoLog(
    String message, {
    LogLevel level = LogLevel.info,
    StackTrace? stackTrace,
  }) {
    logger.logCustom(
      SyncModelCentrifugoTalkerLog(
        message,
        id: id,
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
    logger.logCustom(
      SyncModelTalkerLog(
        message,
        id: id,
        logLevel: level,
        stackTrace: stackTrace,
      ),
    );
  }

  void eventLog(
    String message, {
    LogLevel level = LogLevel.info,
    StackTrace? stackTrace,
  }) {
    logger.logCustom(
      SyncModelEventTalkerLog(
        message,
        id: id,
        logLevel: level,
        stackTrace: stackTrace,
      ),
    );
  }

  void processLog(
    String message, {
    LogLevel level = LogLevel.info,
    StackTrace? stackTrace,
  }) {
    logger.logCustom(
      SyncModelProcessTalkerLog(
        message,
        id: id,
        stackTrace: stackTrace,
        logLevel: level,
      ),
    );
  }
}
