import 'dart:async';
import 'dart:collection';

import 'package:veil/main.dart';

typedef Task<T> = FutureOr<T> Function();

enum TaskPriority { high, low }

class _QueueItem<T> {
  final Task<T> task;
  final TaskPriority priority;
  final Completer<T> completer;
  int retries = 0;

  _QueueItem(this.task, this.priority, this.completer);
}

class PriorityExecutorQueue {
  final _highQueue = Queue<_QueueItem>();
  final _lowQueue = Queue<_QueueItem>();
  bool _isProcessing = false;
  bool _isDisposed = false;

  final int maxRetries;

  PriorityExecutorQueue({this.maxRetries = 3});

  Future<T> add<T>(Task<T> task, {TaskPriority priority = TaskPriority.high}) {
    final completer = Completer<T>();
    final item = _QueueItem(task, priority, completer);

    switch (priority) {
      case TaskPriority.high:
        _highQueue.addLast(item);
        break;
      case TaskPriority.low:
        _lowQueue.addLast(item);
        break;
    }

    _processNext();
    return completer.future;
  }

  void _processNext() async {
    if (_isProcessing || _isDisposed) return;
    _isProcessing = true;

    while (!_isDisposed && (_highQueue.isNotEmpty || _lowQueue.isNotEmpty)) {
      while (_highQueue.isNotEmpty && !_isDisposed) {
        final item = _highQueue.removeFirst();
        await _executeItem(item);
      }

      if (_lowQueue.isNotEmpty && !_isDisposed) {
        final item = _lowQueue.removeFirst();
        await _executeItem(item);
      }
    }

    _isProcessing = false;
  }

  Future<void> _executeItem(_QueueItem item) async {
    try {
      final result = await item.task();
      if (!item.completer.isCompleted) {
        item.completer.complete(result);
      }
    } catch (e, st) {
      if (e.toString().contains('User removed from group')) {
        if (!item.completer.isCompleted) {
          item.completer.completeError(e, st);
        }
        return;
      }
      item.retries++;
      logger.w('Task failed (attempt ${item.retries}): $e');

      if (item.retries < maxRetries) {
        logger.i('Retrying task (${item.retries})...');
        if (item.priority == TaskPriority.high) {
          _highQueue.addLast(item);
        } else {
          _lowQueue.addLast(item);
        }
      } else {
        logger.e('Max retries reached, dropping task');
        if (!item.completer.isCompleted) {
          item.completer.completeError(e, st);
        }
      }
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _highQueue.clear();
    _lowQueue.clear();
  }

  bool get isBusy => _isProcessing;
}
