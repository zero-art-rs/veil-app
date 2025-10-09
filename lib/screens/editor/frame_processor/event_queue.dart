// import 'dart:async';
// import 'dart:collection';

// typedef AsyncTask<T> = FutureOr<T> Function();

// class AsyncQueue {
//   final _queue = Queue<AsyncTask>();
//   final _isProcessingController = StreamController<bool>.broadcast();
//   bool _isProcessing = false;
//   bool _isClosed = false;

//   Stream<bool> get isProcessingStream => _isProcessingController.stream;

//   bool get isProcessing => _isProcessing || _queue.isNotEmpty;

//   void _updateProcessingState(bool value) {
//     final newState = value || _queue.isNotEmpty;
//     if (newState != _isProcessing) {
//       _isProcessing = newState;
//       _isProcessingController.add(_isProcessing);
//     }
//   }

//   Future<T> add<T>(AsyncTask<T> task) {
//     if (_isClosed) throw StateError('Queue is closed');

//     final completer = Completer<T>();
//     _queue.add(() async {
//       try {
//         final result = await task();
//         completer.complete(result);
//       } catch (e, st) {
//         completer.completeError(e, st);
//       }
//     });

//     _processNext();
//     return completer.future;
//   }

//   void _processNext() async {
//     if (_isProcessing || _queue.isEmpty || _isClosed) return;
//     _updateProcessingState(true);

//     while (_queue.isNotEmpty && !_isClosed) {
//       final task = _queue.removeFirst();
//       try {
//         await task();
//       } catch (e, st) {
//         Zone.current.handleUncaughtError(e, st);
//       }
//     }

//     _updateProcessingState(false);
//   }

//   Future<void> dispose() async {
//     _isClosed = true;
//     _queue.clear();
//     await _isProcessingController.close();
//   }
// }
