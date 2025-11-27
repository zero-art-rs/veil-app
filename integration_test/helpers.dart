import 'package:talker_flutter/talker_flutter.dart';
import 'package:uuid/v4.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/managers/sync_provider/local_crdt_storage.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models/account.dart';
import 'package:veil/storage/models/document_state.dart';
import 'package:veil/utils/group_context_factory.dart';

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
    logger: logger,
    saveToDb: false,
    account: owner ?? AccountSecureStorage.instance.account,
    localCrdtStorage: InMemoryLocalCrdtStorage(),
  );

  return syncModel;
}
