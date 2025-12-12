import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/assets/config.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/managers/sync_provider/local_crdt_storage.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/group_context_factory.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.instance.load();
    Talker().info('Logs will be saved to ${Directory.current.path}');
    await DB.instance.openTest(inMemoryPath: 'test_data');
    Hive.init('test_data');
    await RustLib.init();
    AccountSecureStorage.instance.testInit();
  });

  test('Test change user name operation', () async {
    final syncModel = await generateSyncModel(
      logFileName: 'sync_model.log',
      logOutputDir: 'change_user_name',
    );

    await syncModel.testSetup();
    await syncModel.setState(SyncModelStateMode.network);

    final newName = 'New name';
    await syncModel.sendUpdateUserName(name: newName);

    // Waiting for the frame from centrifugo
    await Future.delayed(Duration(seconds: 2));

    final user = syncModel.groupContext.retrieveGroupInfo().members.firstWhere(
      (e) => e.id == syncModel.account.actorId,
    );
    assert(user.name == newName, 'User name was not changed');
  });

  test('Test change group name operation', () async {
    final syncModel = await generateSyncModel(
      logFileName: 'sync_model.log',
      logOutputDir: 'change_group_name',
    );

    await syncModel.testSetup();
    await syncModel.setState(SyncModelStateMode.network);

    final newGroupName = 'New group name';
    await syncModel.sendUpdateGroupName(name: newGroupName);

    // Waiting for the frame from centrifugo
    await Future.delayed(Duration(seconds: 2));

    assert(
      syncModel.groupContext.retrieveGroupInfo().name == newGroupName,
      'Group name was not changed',
    );
  });

  test(
    'Test leave group operation',
    timeout: Timeout(Duration(seconds: 60)),
    () async {
      final syncModel = await generateSyncModel(
        logFileName: 'sync_model.log',
        logOutputDir: 'check_invite_member',
      );

      await syncModel.testSetup();
      await syncModel.setState(SyncModelStateMode.network);
      final _ = await syncModel.sendUnidentifiedInvite();
      await syncModel.setState(SyncModelStateMode.local);

      await Future.delayed(Duration(seconds: 1));
      final parts = await syncModel.groupContext.asParts();

      final reassembledSyncModel = SyncModel(
        documentState: syncModel.documentState,
        groupContext: parts.toGroupContext(
          identitySecretKey: Uint8List.fromList(
            syncModel.account.keypair.rawPrivateKey,
          ),
        ),
        saveToDb: false,
        account: syncModel.account,
        logger: syncModel.logger,
        localCrdtStorage: InMemoryLocalCrdtStorage(),
      );

      await reassembledSyncModel.testSetup();
      await reassembledSyncModel.setState(SyncModelStateMode.network);
      await reassembledSyncModel.sendLeaveGroupFrame();
    },
  );

  test('Check access to centrifugo after keyupdate', () async {
    initTracing();

    final syncModel = await generateSyncModel(
      logFileName: 'sync_model.log',
      logOutputDir: 'check_access_to_centrifugo_after_keyupdate',
    );

    final frame = await syncModel.groupContext.createFrame(content: []);
    await GroupApiClient.instance.sendFrame(
      groupId: syncModel.documentState.id,
      frame: frame,
    );
    await syncModel.groupContext.processFrame(frame: frame);
    final frame2 = await syncModel.groupContext.createFrame(content: []);
    await GroupApiClient.instance.sendFrame(
      groupId: syncModel.documentState.id,
      frame: frame2,
    );

    final challenge1 = await GroupApiClient.instance.getChallenge(
      syncModel.documentState.id,
    );

    final _ = await GroupApiClient.instance.getCentrifugoJWT(
      groupId: syncModel.documentState.id,
      epoch: (await syncModel.groupContext.epoch()).toInt(),
      proof: base64Encode(
        await syncModel.groupContext.signChallenge(
          challenge: base64Decode(challenge1),
        ),
      ),
      challenge: challenge1,
    );
  });

  test(
    'Concurrent keyupdate via send crdt frame',
    timeout: Timeout(Duration(minutes: 60)),
    () async {
      final sendFramesCount = 5;
      final membersCount = 24;
      final logger = Talker();

      logger.info('Group participants count is ${membersCount + 1}');

      final ownerSyncModel = await generateSyncModel(
        logOutputDir: 'concurrent_keyupdate',
        logFileName: 'owner.log',
      );

      await ownerSyncModel.testSetup();
      await ownerSyncModel.setState(SyncModelStateMode.network);
      final links = await generateInviteLinks(ownerSyncModel, membersCount);
      final members = generateAccountList(membersCount);

      var membersSyncModelList = [];
      for (var i = 0; i < membersCount; i++) {
        membersSyncModelList.add(
          await acceptInvite(
            links[i],
            members[i],
            logFileName: 'member_$i.log',
            outputDir: 'concurrent_keyupdate',
          ),
        );
      }

      final List<SyncModel> allMembersList = [
        ownerSyncModel,
        ...membersSyncModelList,
      ];

      final List<Future> workList = [];
      for (final item in allMembersList.indexed) {
        final work = Future(() async {
          for (var i = 0; i < sendFramesCount; i++) {
            if (item.$2.corrupted) {
              throw Exception('Document is corrupted');
            }

            final message = item.$1 == 0
                ? 'owner_message'
                : 'member_message_${item.$1}';

            final blocks = item.$2.documentState.crdt.getBlocks();
            item.$2.documentState.crdt.insertBlock(
              index: blocks.length,
              text: message,
            );

            await item.$2.sendCrdtFrame(
              item.$2.documentState.crdt.getBlocks().join('\n'),
            );

            await Future.delayed(
              Duration(milliseconds: Random().nextInt(500) + 200),
            );
          }
        });

        workList.add(work);
      }

      await Future.wait(workList, eagerError: true);

      final List<Future> workList2 = [];
      for (var syncModel in allMembersList) {
        workList2.add(
          syncModel.queuesProcessListener.isProcessing.firstWhere((e) => !e),
        );
      }

      await Future.wait(workList2);

      // Waiting for remaining tasks in process queue to complete
      await Future.delayed(Duration(seconds: 10));

      final values = allMembersList.map(
        (e) => e.documentState.crdt.getBlocks().join(','),
      );

      for (var value in values) {
        logger.info(value);
      }

      final allEqual = values.every((v) => v == values.first);
      assert(allEqual, 'Different crdt document state!');
    },
  );
}
