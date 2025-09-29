import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:rxdart/subjects.dart';
import 'package:veil/api/centrifuge.dart';
import 'package:veil/api/client.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/change_manager.dart';
import 'package:veil/managers/sync_provider/pending_sync_model.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/group_context_factory.dart';

class SyncProvider {
  final _centrifugo = CentrifugeProvider.instance;
  final _db = DB.instance;
  final _api = GroupApiClient.instance;
  final _accountStorage = AccountStorage.instance;
  final _changeManager = ChangeManager.instance;

  Account? _acc;
  Account get _account => _acc!;

  List<SyncProviderModel> get current => subject.value;
  BehaviorSubject<List<SyncProviderModel>> subject = BehaviorSubject.seeded([]);

  static final instance = SyncProvider();

  Future<void> init() async {
    final documents = await _db.getDocumentList();
    _acc = await _accountStorage.getAccount();

    if (_acc == null) {
      throw Exception('No account, unreachable flow');
    }

    for (final doc in documents) {
      final groupContext = doc.groupContextParts.toGroupContext(
        identitySecretKey: Uint8List.fromList(_account.keypair.rawPrivateKey),
      );

      await add(doc, groupContext);
      await DB.instance.updateDocument(doc: doc, parts: groupContext.asParts());
    }
  }

  Future<SyncProviderModel> add(
    Document document,
    BGroupContext groupContext, {
    insertToDb = false,
  }) async {
    final syncModel = await _synchronizeDocument(document, groupContext);
    if (insertToDb) {
      await _db.insertDocument(document: document);
    }
    current.add(syncModel);
    subject.add(current);

    return syncModel;
  }

  Future<SyncProviderModel> addFromInvite(
    Document document,
    BPendingGroupContext pendingGroupContext, {
    required BUser user,
  }) async {
    final groupContext = await _upgradeGroupContext(
      document,
      pendingGroupContext,
      user,
    );

    final syncModel = await _synchronizeDocument(document, groupContext);

    await _db.insertDocument(document: document);
    current.add(syncModel);
    subject.add(current);

    return syncModel;
  }

  Future<void> remove(String chatId) async {
    final syncModel = subject.value
        .where((element) => element.document.id == chatId)
        .firstOrNull;

    if (syncModel == null) {
      logger.e('no sync model');
      return;
    }

    await syncModel.dispose();

    await _db.transaction((database) async {
      await database.deleteDocument(syncModel.document.id);
    });

    current.removeWhere((element) => element.document.id == chatId);
    subject.add(current);
  }

  SyncProviderModel get(String chatId) {
    return current.firstWhere((element) => element.document.id == chatId);
  }

  List<SyncProviderModel> getAll() {
    return current;
  }

  Future<SyncProviderModel> _synchronizeDocument(
    Document doc,
    BGroupContext groupContext,
  ) async {
    final challenge = await _api.getChallenge(doc.id);

    final jwt = await _api.getCentrifugoJWT(
      groupId: doc.id,
      epoch: groupContext.getEpoch().toInt(),
      proof: base64Encode(
        groupContext.signChallenge(challenge: base64Decode(challenge)),
      ),
      challenge: challenge,
    );

    final stream = await _centrifugo.connect(jwt);
    _changeManager.setup(doc.id);

    final syncModel = SyncProviderModel.withListener(
      doc,
      groupContext,
      jwt,
      stream,
    );

    await syncModel.synchronizeInitially();

    return syncModel;
  }

  Future<BGroupContext> _upgradeGroupContext(
    Document doc,
    BPendingGroupContext pendingGroupContext,
    BUser user,
  ) async {
    final challenge = await _api.getChallenge(doc.id);

    final jwt = await _api.getCentrifugoJWT(
      groupId: doc.id,
      epoch: pendingGroupContext.getEpoch().toInt(),
      proof: base64Encode(
        pendingGroupContext.signChallenge(challenge: base64Decode(challenge)),
      ),
      challenge: challenge,
    );

    final stream = await _centrifugo.connect(jwt);

    final pendingSyncModel = SyncPendingProviderModel(
      document: doc,
      groupContext: pendingGroupContext,
      jwt: jwt,
    );

    pendingSyncModel.listenCentrifugo(stream);
    return await pendingSyncModel.synchronizeInitially(user);
  }
}
