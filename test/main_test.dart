import 'package:async_queue/async_queue.dart';
import 'package:diffutil_dart/diffutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test diff behaviour', () async {
    final queue = AsyncQueue.autoStart();

    queue.addJob(
      () async {
        try {
          throw Exception('error');
        } catch (e) {
          queue.retry();
        }
      },
      label: '5000000',
      retryTime: 5,
    );

    await Future.delayed(Duration(seconds: 5));

    print(queue.getJobInfo('5000000'));
  });
}
