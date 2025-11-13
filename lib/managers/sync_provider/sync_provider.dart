import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:rxdart/subjects.dart';
import 'package:veil/api/centrifugo.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/chat/chat_manager.dart';
import 'package:veil/managers/chat/hive_chat_controller.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/managers/sync_provider/sync_model_errors.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/local_state.dart';

class SyncProvider {
  final _db = DB.instance;
  final _api = GroupApiClient.instance;

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

      if (documentState.isLocal) {
        await _addLocal(documentState, groupContext);
      } else {
        await _addRemote(documentState, groupContext);
      }
    }
  }

  Future<void> _addRemote(
    DocumentState documentState,
    BGroupContext groupContext,
  ) async {
    try {
      await add(documentState, groupContext);
    } catch (e, st) {
      if (isUserRemovedError(e)) {
        logger.info('User removed from group, making local only');
        await LocalStateUtils.instance.makeDocumentLocal(documentState);
        await _addLocal(documentState, groupContext);
      } else {
        _addCorrupted(documentState, groupContext);
        logger.error(
          'Failed to add sync model, marking it as corrupted: $e\n$st',
        );
      }
    }
  }

  Future<void> add(
    DocumentState documentState,
    BGroupContext groupContext, {
    bool insertToDb = false,
    bool allowFullDocument = false,
  }) async {
    final syncModel = await _synchronizeDocument(
      documentState,
      groupContext,
      allowFullDocument: allowFullDocument,
    );

    if (insertToDb) {
      await _db.insertDocumentState(documentState: documentState);
    }

    current.add(syncModel);
    subject.add(current);
  }

  Future<void> _addLocal(
    DocumentState documentState,
    BGroupContext groupContext,
  ) async {
    final hive = await Hive.openBox(documentState.id);
    final hiveChatController = HiveChatController(hive);

    final syncModel = SyncModel(
      documentState: documentState,
      groupContext: groupContext,
      listener: null,
      chatManager: ChatManager(controller: hiveChatController),
    );

    current.add(syncModel);
    subject.add(current);
  }

  Future<void> _addCorrupted(
    DocumentState documentState,
    BGroupContext groupContext,
  ) async {
    final hive = await Hive.openBox(documentState.id);
    final hiveChatController = HiveChatController(hive);

    final syncModel = SyncModel(
      documentState: documentState,
      groupContext: groupContext,
      listener: null,
      chatManager: ChatManager(controller: hiveChatController),
      corrupted: true,
    );

    current.add(syncModel);
    subject.add(current);
  }

  Future<void> remove(String chatId) async {
    final syncModel = subject.value
        .where((element) => element.documentState.id == chatId)
        .firstOrNull;

    if (syncModel == null) {
      logger.error('no sync model');
      return;
    }

    if (!syncModel.isLocal && !syncModel.corrupted) {
      await syncModel.leaveGroup();
      await syncModel.dispose();
    }

    await Hive.box(syncModel.documentState.id).deleteFromDisk();
    await _db.deleteDocumentState(syncModel.documentState.id);

    current.removeWhere((element) => element.documentState.id == chatId);
    subject.add(current);
  }

  SyncModel get(String chatId) {
    return current.firstWhere((element) => element.documentState.id == chatId);
  }

  List<SyncModel> getAll() {
    return current;
  }

  Future<SyncModel> _synchronizeDocument(
    DocumentState documentState,
    BGroupContext groupContext, {
    bool allowFullDocument = false,
  }) async {
    final challenge = await _api.getChallenge(documentState.id);

    final jwt = await _api.getCentrifugoJWT(
      groupId: documentState.id,
      epoch: (await groupContext.epoch()).toInt(),
      proof: base64Encode(
        await groupContext.signChallenge(challenge: base64Decode(challenge)),
      ),
      challenge: challenge,
    );

    final hive = await Hive.openBox(documentState.id);
    final hiveChatController = HiveChatController(hive);

    final syncModel = SyncModel(
      documentState: documentState,
      groupContext: groupContext,
      listener: null,
      chatManager: ChatManager(controller: hiveChatController),
    );

    final listener = CentrifugoListener(
      streamCallback: (response) async {
        logger.info(
          'Centrifugo event received, data: ${response.data}, event: ${response.event}, id: ${response.id}',
        );

        if (response.data.isEmpty) return;
        try {
          final rawJson = json.decode(response.data);
          if (rawJson['pub'] == null) return;

          logger.debug(
            'Centrifugo received data: ${response.data}, event: ${response.event}, id: ${response.id}',
          );

          final frameBytes = base64Decode(rawJson['pub']['data'].toString());

          final frame = SPFrame.fromBuffer(frameBytes);
          await syncModel.processFrame(frame);
        } catch (e) {
          logger.error(
            'Failed to process frame, highlighting document as corrupted: $e',
          );

          await syncModel.markAsCorrupted();
        }
      },
    );

    syncModel.listener = listener;

    await listener.connect(jwt);

    try {
      await syncModel.synchronizeInitially(
        allowFullDocument: allowFullDocument,
      );
      await syncModel.applyBufferedFrames();
      syncModel.listenCentrifugo();
    } catch (e) {
      logger.error(
        'Failed to initially synchronize document, highlighting document as corrupted: $e',
      );

      await syncModel.markAsCorrupted();
    }

    return syncModel;
  }

  void checkCentrifugoConnection() {
    for (final syncModel in current) {
      // syncModel.listener?.
    }
  }
}
