import 'dart:async';

import 'package:async_queue/async_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/change_manager.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/utils/executor.dart';

void main() {
  group('Test rx', () {
    test('test behaviour subject behaviour', () {
      final subject = BehaviorSubject<int>();

      subject.add(1);

      final value = subject.stream.valueOrNull;

      expect(value, 1);
    });

    test('test stream broadcast behaviour', () {
      final streamController = StreamController.broadcast();
      streamController.add(1);

      streamController.stream.listen((event) {
        // Should not be called
        expect(event, 2);
      });
    });
  });

  group('Executor tests', () {
    test('Shared value test', () async {
      final executor = PriorityExecutorQueue();

      var sharedValue = 0;
      Future.delayed(Duration.zero, (() async {
        await executor.add(() {
          sharedValue = 1;
          logger.i('execute first sharedValue: $sharedValue');
        });
      }));

      Future.delayed(Durations.short1, (() async {
        await executor.add(() {
          sharedValue = 2;
          logger.i('execute first sharedValue: $sharedValue');
        });
      }));

      Future.delayed(Durations.short2, (() async {
        await executor.add(() {
          sharedValue = 100;
          logger.i('execute first sharedValue: $sharedValue');
        }, priority: TaskPriority.low);
      }));

      Future(() async {
        try {
          await executor.add(() async {
            await Future.delayed(Durations.medium1, (() async {
              throw Exception('error');
            }));
          }, priority: TaskPriority.low);
        } catch (e) {
          logger.e('Error: $e');
        }
      });

      Future.delayed(Duration.zero, (() async {
        await executor.add(() {
          sharedValue = 3;
          logger.i('execute first sharedValue: $sharedValue');
        });
      }));

      await Future(() async {
        while (true) {
          if (executor.isBusy) {
            await Future.delayed(Durations.extralong4);
          } else {
            break;
          }
        }
      });
    });

    test('Incorrect state, sync and process', () async {
      var state = 0;
      final executor = PriorityExecutorQueue();

      Future.delayed(Durations.medium3, () async {
        await executor.add(() async {
          await Future.delayed(Durations.short1);
          logger.i('executed');
          state++;
        });
      });

      Future.delayed(Durations.medium1, () async {
        await executor.add(() async {
          await Future.delayed(Durations.short4);
          logger.i('executed2');
          state++;
        });
      });

      await Future(() async {
        await executor.add(() async {
          await Future.delayed(Durations.short4);

          if (state != 2) {
            throw Exception('Incorrect state');
          }

          logger.i('executed3');
          state++;
        }, priority: TaskPriority.low);
      });

      await Future(() async {
        while (true) {
          if (executor.isBusy) {
            await Future.delayed(Durations.extralong4);
          } else {
            break;
          }
        }
      });
    });
  });

  group('Changes manager initial sync test', () {
    test('test change manager initial flow', () async {
      final changesManager = ChangeManager.instance;
      changesManager.setup('1');

      changesManager.addFrame(
        groupId: '1',
        frame: SPFrame(),
        sequenceNumber: 0,
      );

      final bufferedFrames = changesManager.getFrames('1');
      expect(bufferedFrames.values.length, 1);

      changesManager.stream('1').listen((e) {
        // first frame should be ommited
        logger.i('received frame: $e');
        expect(e.seqNum.toInt(), 1);
      });

      changesManager.addFrame(
        groupId: '1',
        frame: SPFrame(),
        sequenceNumber: 1,
      );

      await Future.delayed(Durations.extralong4);
    });
  });

  test('Simplified sync flow', () async {
    final executor = PriorityExecutorQueue();
    final streamController = StreamController();
    final frameQueue = AsyncQueue();

    var state = 0;

    // Centrifugo imitation
    Future(() async {
      for (var i = 1; i <= 3; i++) {
        streamController.add(i);
        await Future.delayed(Durations.short1);
      }
    });

    // process frame imitation
    streamController.stream.listen((e) async {
      frameQueue.addJob(
        () async => executor.add(() {
          state++;
          logger.i('state $state');
        }),
      );

      await frameQueue.start();
    });

    // write operation imitation
    await Future(() async {
      await executor.add(() async {
        await Future.delayed(Durations.medium1);
        if (state != 3) {
          throw Exception('Incorrect state');
        }

        logger.i('synced state');
        state++;
      }, priority: TaskPriority.low);
    });
  });
}
