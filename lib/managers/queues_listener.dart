import 'dart:async';

import 'package:queue/queue.dart';
import 'package:rxdart/rxdart.dart';

class QueuesListener {
  final _queue = Queue();
  final List<Stream<int>> streams;
  final List<bool> processStatuses;
  final List<StreamSubscription<int>> _subscriptions = [];

  final BehaviorSubject<bool> _isProcessing = BehaviorSubject.seeded(false);
  Stream<bool> get isProcessing => _isProcessing.stream;

  QueuesListener({required this.streams})
    : processStatuses = List.filled(streams.length, false);

  void listen() {
    for (final (index, queue) in streams.indexed) {
      final subscribtion = queue.listen((e) {
        _queue.add(() async {
          processStatuses[index] = e != 0;
          _notifyStatus();
        });
      });

      _subscriptions.add(subscribtion);
    }
  }

  void _notifyStatus() {
    final isProcessing = processStatuses.any((e) => e);
    _isProcessing.add(isProcessing);
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
  }
}
