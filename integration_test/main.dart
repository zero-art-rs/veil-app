import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:uuid/v4.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/managers/sharing/deeplink_manager.dart';
import 'package:veil/managers/sync_provider/local_crdt_storage.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models/account.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/file_talker_history.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await DB.instance.openTest(inMemoryPath: 'test_data');
    Hive.init('test_data');
    await RustLib.init();
    initTracing();
    AccountSecureStorage.instance.testInit();
  });

  test('Check access to centrifugo after keyupdate', () async {
    final owner = Account.withName('owner');
    final id = UuidV4().generate();

    final syncModel = await createSyncModel(
      groupID: id,
      owner: owner,
      logger: Talker(),
    );

    final frame = await syncModel.groupContext.createFrame(content: []);
    await GroupApiClient.instance.sendFrame(groupId: id, frame: frame);
    await syncModel.groupContext.processFrame(frame: frame);
    final frame2 = await syncModel.groupContext.createFrame(content: []);
    await GroupApiClient.instance.sendFrame(groupId: id, frame: frame2);

    final challenge1 = await GroupApiClient.instance.getChallenge(id);

    final _ = await GroupApiClient.instance.getCentrifugoJWT(
      groupId: id,
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
    timeout: Timeout(Duration(minutes: 10)),
    () async {
      final logger = Talker();
      logger.info(Directory.current.path);

      await Directory('integration_test/output').create(recursive: true);
      print(Directory.current);
      final ownerFile = File('integration_test/output/owner_1.log');
      final memberFile = File('integration_test/output/member_1.log');

      final ownerLogger = Talker(
        history: FileTalkerHistory(TalkerSettings(), file: ownerFile),
      );

      final memberLogger = Talker(
        history: FileTalkerHistory(TalkerSettings(), file: memberFile),
      );

      final ownerAccount = Account.withName('Owner');
      final memberAccount = Account.withName('Member');

      final ownerSyncModel = await createSyncModel(
        logger: ownerLogger,
        owner: ownerAccount,
      );
      await ownerSyncModel.testSetup();
      await ownerSyncModel.setState(SyncModelStateMode.network);

      var md = ['Hello!'];
      await ownerSyncModel.sendCrdtFrame(md.join('\n'));

      final link = await ownerSyncModel.createUnidentifiedMemberInviteLink();
      final documentLink = DeeplinkManager.instance.retrieveDocumentDeepLink(
        Uri.parse(link),
      );

      final memberSyncModel = await memberAccount.acceptInvite(
        documentLink!.inviteData,
        localCrdtStorage: InMemoryLocalCrdtStorage(),
        saveToDb: false,
        logger: memberLogger,
      );

      await memberSyncModel.testSetup();
      await memberSyncModel.setState(
        SyncModelStateMode.network,
        allowFullDocument: true,
      );

      final ownerWork = Future(() async {
        try {
          await Future.delayed(Duration(seconds: 5));
          for (var i = 0; i < 25; i++) {
            md.add('owner message $i');
            await ownerSyncModel.sendCrdtFrame(md.join('\n'));
          }
        } catch (e) {
          ownerLogger.error('owner work error: $e');
          await ownerSyncModel.clearState(
            disableNetworkListener: true,
            disableStateBroadcast: true,
            cancelPendingTasks: true,
          );
          return;
        }
      });

      final memberWork = Future(() async {
        await Future.delayed(Duration(seconds: 5));
        try {
          for (var i = 0; i < 25; i++) {
            md.add('member message $i');
            await memberSyncModel.sendCrdtFrame(md.join('\n'));
          }
        } catch (e) {
          memberLogger.error('member work error: $e');
          await memberSyncModel.clearState(
            disableNetworkListener: true,
            disableStateBroadcast: true,
            cancelPendingTasks: true,
          );
          return;
        }
      });

      await Future.wait([ownerWork, memberWork]);
      await Future.delayed(Duration(seconds: 5));

      await ownerSyncModel.queuesProcessListener.isProcessing.firstWhere(
        (e) => !e,
      );
      await memberSyncModel.queuesProcessListener.isProcessing.firstWhere(
        (e) => !e,
      );

      logger.info(
        'owner crdt blocks: ${ownerSyncModel.documentState.crdt.getBlocks()}',
      );

      logger.info(
        'member crdt blocks: ${memberSyncModel.documentState.crdt.getBlocks()}',
      );

      assert(
        ownerSyncModel.documentState.crdt.getBlocks().join() ==
            memberSyncModel.documentState.crdt.getBlocks().join(),
      );
    },
  );
}
