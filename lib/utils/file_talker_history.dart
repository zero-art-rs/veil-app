import 'dart:io';
import 'package:talker/talker.dart';

/// TalkerHistory implementation that stores logs in a file.
class FileTalkerHistory implements TalkerHistory {
  FileTalkerHistory(
    this.settings, {
    required this.file,
    this.keepInMemory = false,
  }) {
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
  }

  /// Where to store history settings
  final TalkerSettings settings;

  /// Log file
  final File file;

  /// Keep logs in memory (optional)
  final bool keepInMemory;

  /// Internal memory list
  final List<TalkerData> _history = [];

  @override
  List<TalkerData> get history => _history;

  @override
  void clean() {
    if (settings.useHistory) {
      // Clear memory
      _history.clear();

      // Clear file
      file.writeAsStringSync('');
    }
  }

  @override
  void write(TalkerData data) {
    if (!settings.useHistory || !settings.enabled) {
      return;
    }

    // Trim old items if needed
    if (settings.maxHistoryItems <= _history.length) {
      _history.removeAt(0);
    }

    // Save in memory (optional)
    if (keepInMemory) {
      _history.add(data);
    }

    // Append to file
    file.writeAsStringSync(
      '${data.generateTextMessage()}\n',
      mode: FileMode.append,
    );
  }
}
