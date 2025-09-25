import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:rxdart/subjects.dart';
import 'package:zk_notion_app/api/centrifuge.dart';
import 'package:zk_notion_app/api/client.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/managers/change_manager.dart';
import 'package:zk_notion_app/protos/zero_art.pb.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:zk_notion_app/src/rust/api/group_context.dart';
import 'package:zk_notion_app/storage/account_storage.dart';
import 'package:zk_notion_app/storage/models.dart';
import 'package:zk_notion_app/storage/sqlite/db.dart';
import 'package:zk_notion_app/utils/group_context_factory.dart';
import 'package:zk_notion_app/utils/payload.dart';

enum ProcessingStatus { initalProcess, idle, editing }

class SyncProviderModel {
  final Document document;
  final BGroupContext groupContext;
  final String jwt;
  late final StreamSubscription<SSEModel> listener;
  BehaviorSubject<ProcessingStatus> status = BehaviorSubject.seeded(
    ProcessingStatus.initalProcess,
  );

  SyncProviderModel({
    required this.document,
    required this.groupContext,
    required this.jwt,
  });

  Future<void> synchronizeInitially() async {
    logger.i('document.sequenceNumber ${document.sequenceNumber}');
    logger.i('group epoch ${groupContext.getEpoch().toInt()}');

    final signature = groupContext.signWithTk(groupId: document.id, nonce: [0]);

    // var seqnum = 0;
    while (true) {
      try {
        final result = await GroupApiClient.instance.getFrames(
          epoch: groupContext.getEpoch().toInt(),
          groupId: document.id,
          signature: base64UrlEncode(signature),
          nonce: base64UrlEncode([0]),
          messageSequenceNumber: document.sequenceNumber,
        );

        // if (result.spFrames.isEmpty) {
        // logger.d('No new frames');
        // break;
        // }

        // print(result.spFrames.);
        // logger.i('-------RECEIVED FRAMES');
        // for (final spFrame in result.spFrames) {
        //   logger.i('spFrame.seqNum.toInt() ${spFrame.seqNum.toInt()}');
        //   logger.i(
        //     'spFrame.seqNum.toInt() ${spFrame.frame.frame.epoch.toInt()}',
        //   );
        //   logger.i('spFrame.seqNum.toInt() ${spFrame.frame}');
        // }
        // logger.i('--------RECEIVED FRAMES END');

        if (result.spFrames.first.seqNum.toInt() == document.sequenceNumber) {
          break;
        }

        for (final spFrame in result.spFrames.reversed) {
          final rawFramePayloads = groupContext.processFrame(
            spFrame: spFrame.writeToBuffer(),
          );

          // logger.i('CHECK LENGTH OF PAYLOADS ${rawFramePayloads.length}');

          // If rawFramePayloads is empty,
          // it indicates that the frame belongs to the current user,
          // thus processing is unnecessary.

          for (final rawPayload in rawFramePayloads) {
            final payload = Payload.fromBuffer(rawPayload);

            final (crdt, _) = PayloadUtils.instance.exposePayload(payload);

            if (crdt == null) continue;

            switch (crdt.kind) {
              case ExposedCRDTPayloadKind.incrementalChange:
                logger.d('Received incremental change');
                document.automergeDoc.loadIncremental(
                  bytes: crdt.crdt.incrementalChange,
                );
                document.automergeDoc.emptyChange();
                document.automergeDoc.commit();
              case ExposedCRDTPayloadKind.fullDocument:
                logger.d('Received full document');
                document.automergeDoc = BAutoCommit.load(
                  data: crdt.crdt.fullDocument,
                );
            }
          }
        }

        // seqnum = result.spFrames.first.seqNum.toInt();
        document.sequenceNumber = result.spFrames.first.seqNum.toInt();
      } catch (err) {
        logger.e('Sync provider inital process error: $err');
      }
    }
  }

  /// Listen, transform data to frames send to processor.
  void listenCentrifugo(Stream<SSEModel> stream, ChangeManager changeManager) {
    listener = stream.listen(
      (event) {
        if (event.data == null || event.data!.isEmpty) return;

        final rawJson = json.decode(event.data!);
        if (rawJson['pub'] == null) return;

        final frameBytes = base64Decode(rawJson['pub']['data'].toString());

        final frame = SPFrame.fromBuffer(frameBytes);

        changeManager.addFrame(
          groupId: document.id,
          frame: frame,
          sequenceNumber: frame.seqNum.toInt(),
        );
      },
      onError: (error, [stackTrace]) {
        logger.e('Centrifugo error: $error, trace: $stackTrace');
      },
      onDone: () {
        logger.i('Centrifugo done');
      },
      cancelOnError: false,
    );
  }

  Future<void> dispose() async {
    logger.i('Sync provider disposed');
    await listener.cancel();
  }
}

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

    final syncModel = SyncProviderModel(
      document: doc,
      groupContext: groupContext,
      jwt: jwt,
    );

    syncModel.listenCentrifugo(stream, _changeManager);
    await syncModel.synchronizeInitially();

    return syncModel;
  }
}
