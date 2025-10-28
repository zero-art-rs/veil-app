import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:rxdart/subjects.dart';
import 'package:veil/api/centrifuge.dart';
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
  final _centrifugo = CentrifugeProvider.instance;
  final _db = DB.instance;
  final _api = GroupApiClient.instance;

  List<SyncModel> get current => subject.value;
  BehaviorSubject<List<SyncModel>> subject = BehaviorSubject.seeded([]);

  static final instance = SyncProvider._();
  SyncProvider._();

  Future<void> init() async {
    final documents = await _db.getDocumentList();

    for (final doc in documents) {
      final groupContext = doc.groupContextParts.toGroupContext(
        identitySecretKey: Uint8List.fromList(
          AccountSecureStorage.instance.account.keypair.rawPrivateKey,
        ),
      );

      if (doc.localOnly) {
        await _addLocal(doc, groupContext);
      } else {
        await _addRemote(doc, groupContext);
      }
    }
  }

  Future<void> _addRemote(Document doc, BGroupContext groupContext) async {
    try {
      await add(doc, groupContext);
    } catch (e, st) {
      if (isUserRemovedError(e)) {
        logger.i('User removed from group, making local only');
        await LocalStateUtils.instance.makeDocumentLocal(doc);
        await _addLocal(doc, groupContext);
      } else {
        _addCorrupted(doc, groupContext);
        logger.e('Failed to add sync model, marking it as corrupted: $e\n$st');
      }
    }
  }

  Future<void> add(
    Document document,
    BGroupContext groupContext, {
    bool insertToDb = false,
    bool allowFullDocument = false,
  }) async {
    final syncModel = await _synchronizeDocument(
      document,
      groupContext,
      allowFullDocument: allowFullDocument,
    );

    if (insertToDb) {
      await _db.insertDocument(document: document);
    }

    current.add(syncModel);
    subject.add(current);
  }

  Future<void> _addLocal(Document document, BGroupContext groupContext) async {
    final hive = await Hive.openBox(document.id);
    final hiveChatController = HiveChatController(hive);

    final syncModel = SyncModel(
      document: document,
      groupContext: groupContext,
      listener: null,
      chatManager: ChatManager(controller: hiveChatController),
    );

    current.add(syncModel);
    subject.add(current);
  }

  Future<void> _addCorrupted(
    Document document,
    BGroupContext groupContext,
  ) async {
    final hive = await Hive.openBox(document.id);
    final hiveChatController = HiveChatController(hive);

    final syncModel = SyncModel(
      document: document,
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
        .where((element) => element.document.id == chatId)
        .firstOrNull;

    if (syncModel == null) {
      logger.e('no sync model');
      return;
    }

    if (!syncModel.isLocal && !syncModel.corrupted) {
      await syncModel.leaveGroup();
      await syncModel.dispose();
    }
    await _db.deleteDocument(syncModel.document.id);

    current.removeWhere((element) => element.document.id == chatId);
    subject.add(current);
  }

  SyncModel get(String chatId) {
    return current.firstWhere((element) => element.document.id == chatId);
  }

  List<SyncModel> getAll() {
    return current;
  }

  Future<SyncModel> _synchronizeDocument(
    Document doc,
    BGroupContext groupContext, {
    bool allowFullDocument = false,
  }) async {
    final challenge = await _api.getChallenge(doc.id);

    final jwt = await _api.getCentrifugoJWT(
      groupId: doc.id,
      epoch: (await groupContext.epoch()).toInt(),
      proof: base64Encode(
        await groupContext.signChallenge(challenge: base64Decode(challenge)),
      ),
      challenge: challenge,
    );

    final stream = await _centrifugo.connect(jwt);
    final hive = await Hive.openBox(doc.id);
    final hiveChatController = HiveChatController(hive);

    final syncModel = SyncModel(
      document: doc,
      groupContext: groupContext,
      listener: null,
      chatManager: ChatManager(controller: hiveChatController),
    );

    final listener = stream.listen(
      (event) async {
        if (event.data == null || event.data!.isEmpty) return;

        final rawJson = json.decode(event.data!);
        if (rawJson['pub'] == null) return;

        final frameBytes = base64Decode(rawJson['pub']['data'].toString());

        final frame = SPFrame.fromBuffer(frameBytes);

        try {
          await syncModel.processFrame(frame);
        } catch (e) {
          logger.e(
            'Failed to process frame, highlighting document as corrupted: $e',
          );

          await syncModel.highlightCorrupted();
        }
      },
      onError: (error, [stackTrace]) {
        logger.e('Centrifugo error: $error, trace: $stackTrace');
      },
      onDone: () {
        logger.i('Centrifugo done');
      },
      cancelOnError: false,
    );

    syncModel.listener = listener;
    try {
      await syncModel.synchronizeInitially(
        allowFullDocument: allowFullDocument,
      );
      await syncModel.applyBufferedFrames();
      syncModel.listenProcess();
    } catch (e) {
      logger.e(
        'Failed to initially synchronize document, highlighting document as corrupted: $e',
      );

      await syncModel.highlightCorrupted();
    }

    return syncModel;
  }
}
