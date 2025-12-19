import 'dart:io';

import 'package:talker_flutter/talker_flutter.dart';
import 'package:uuid/v4.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/managers/sharing/deeplink_manager.dart';
import 'package:veil/managers/sync_provider/local_crdt_storage.dart';
import 'package:veil/managers/sync_provider/logger/logger.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models/account.dart';
import 'package:veil/storage/models/document_state.dart';
import 'package:veil/utils/file_talker_history.dart';
import 'package:veil/utils/group_context_factory.dart';

const ownerIndex = 0;

Future<SyncModel> createSyncModel({
  String groupName = 'test',
  String? groupID,
  Account? owner,
  Talker? logger,
}) async {
  final id = groupID ?? UuidV4().generate();

  final (groupContext, frame) = await GroupContextFactory.createGroupContext(
    groupName: groupName,
    groupID: id,
    owner: owner ?? AccountSecureStorage.instance.account,
  );

  await GroupApiClient.instance.sendFrame(groupId: id, frame: frame);

  final documentState = DocumentState(
    id: id,
    crdt: BAutoCommit.withOwner(
      actorId: owner?.actorId ?? AccountSecureStorage.instance.account.actorId,
    ),
    createdAt: DateTime.now(),
    groupContextParts: await groupContext.asParts(),
  );

  SyncModel syncModel = SyncModel(
    documentState: documentState,
    groupContext: groupContext,
    logger: logger != null ? SyncModelLogger(logger, documentState.id) : null,
    saveToDb: false,
    account: owner ?? AccountSecureStorage.instance.account,
    localCrdtStorage: InMemoryLocalCrdtStorage(),
  );

  return syncModel;
}

Future<List<SyncModel>> getSyncModels(int count) async {
  List<SyncModel> models = [];

  for (var i = 0; i < count; i++) {
    final file = File('integration_test/output/member_$i.log');

    final talker = Talker(
      history: FileTalkerHistory(TalkerSettings(), file: file),
    );

    models.add(
      await createSyncModel(
        owner: Account.withName('Member $i'),
        logger: talker,
      ),
    );
  }

  return models;
}

Future<SyncModel> generateSyncModel({
  String logFileName = 'syncModel.log',
  String logOutputDir = 'general',
  String accountName = 'owner',
  bool printLogsToConsole = true,
}) async {
  final talker = Talker(
    settings: TalkerSettings(useConsoleLogs: printLogsToConsole),
    history: FileTalkerHistory(
      TalkerSettings(),
      file: File('integration_test/$logOutputDir/$logFileName'),
    ),
  );
  return await createSyncModel(
    owner: Account.withName(accountName),
    logger: talker,
  );
}

List<Account> generateAccountList(int count) {
  List<Account> accounts = [];

  for (var i = 0; i < count; i++) {
    accounts.add(Account.withName('Member $i'));
  }

  return accounts;
}

Future<List<String>> generateInviteLinks(SyncModel syncModel, int count) async {
  List<String> links = [];

  for (var i = 0; i < count; i++) {
    final link = await syncModel.sendUnidentifiedInvite();
    links.add(link);
  }

  return links;
}

Future<SyncModel> acceptInvite(
  String invite,
  Account account, {
  String outputDir = 'general',
  String logFileName = 'syncModel.log',
  bool printLogsToConsole = true,
}) async {
  final documentDeepLink = DeeplinkManager.instance.retrieveDocumentDeepLink(
    Uri.parse(invite),
  );

  final talker = Talker(
    settings: TalkerSettings(useConsoleLogs: printLogsToConsole),
    history: FileTalkerHistory(
      TalkerSettings(),
      file: File('integration_test/$outputDir/$logFileName'),
    ),
  );

  final syncModel = await account.acceptInvite(
    documentDeepLink!.inviteData,
    localCrdtStorage: InMemoryLocalCrdtStorage(),
    saveToDb: false,
    logger: talker,
  );

  await syncModel.testSetup();
  await syncModel.setState(SyncModelStateMode.network, allowFullDocument: true);

  return syncModel;
}
