import 'package:flutter_test/flutter_test.dart';
import 'package:queue/queue.dart';

void main() {
  test('test diff behaviour', () async {
    final queue = Queue();

    try {
      await queue.add(() async {
        await Future.delayed(Duration(seconds: 3));
      });
    } catch (e) {
      print(e);
    }

    queue.cancel();

    try {
      await queue.add(() async {
        await Future.delayed(Duration(seconds: 3));
      });
    } on QueueCancelledException {
      print('Cancelled');
    } catch (e) {
      print(e);
    }
  });
}
