import 'dart:async';
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:rxdart/subjects.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/sqlite/db.dart';

class SyncProvider {
  final _db = DB.instance;

  List<SyncModel> get current => subject.value;
  BehaviorSubject<List<SyncModel>> subject = BehaviorSubject.seeded([]);

  static final instance = SyncProvider._();
  SyncProvider._();

  Future<void> init() async {
    final documentStateList = await _db.getDocumentStateList();

    for (final documentState in documentStateList) {
      final groupContext = documentState.groupContextParts.toGroupContext(
        identitySecretKey: Uint8List.fromList(
          AccountSecureStorage.instance.account.keypair.rawPrivateKey,
        ),
      );

      await add(
        SyncModel(
          documentState: documentState,
          groupContext: groupContext,
          localCrdtStorage: DB.instance,
        ),
      );
    }
  }

  Future<void> add(
    SyncModel syncModel, {
    bool insertToDb = false,
    bool allowFullDocument = false,
  }) async {
    syncModel.setup(allowFullDocument: allowFullDocument);

    if (insertToDb) {
      await _db.insertDocumentState(documentState: syncModel.documentState);
    }

    current.add(syncModel);
    subject.add(current);
  }

  Future<void> remove(String id) async {
    final syncModel = subject.value
        .where((element) => element.documentState.id == id)
        .firstOrNull;

    if (syncModel == null) {
      logger.error('no sync model with id $id found to remove');
      return;
    }

    if (!syncModel.isLocal && !syncModel.corrupted) {
      await syncModel.sendLeaveGroupFrame();
      await syncModel.clearState(
        disableNetworkListener: true,
        disableStateBroadcast: true,
        cancelPendingTasks: true,
      );
    }

    await Hive.box(syncModel.documentState.id).deleteFromDisk();
    await _db.deleteDocumentState(syncModel.documentState.id);

    current.removeWhere((element) => element.documentState.id == id);
    subject.add(current);
  }

  SyncModel get(String chatId) {
    return current.firstWhere((element) => element.documentState.id == chatId);
  }

  List<SyncModel> getAll() {
    return current;
  }
}
