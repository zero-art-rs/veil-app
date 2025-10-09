import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:async_queue/async_queue.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/change_manager.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/managers/sync_provider/sync_model_executor.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/screens/doc_members.dart';
import 'package:veil/screens/history_page.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/consts.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/editor_automerge.dart';
import 'package:veil/utils/group_context_factory.dart';
import 'package:veil/utils/payload.dart';
import 'package:veil/widgets/banner.dart';

enum EditorModes { edit, view }

class EditorPageVm extends ChangeNotifier {
  final mdEditor = TextEditingController();
  final _changeManager = ChangeManager.instance;

  final SyncProviderModel syncModel;
  String? _hashBeforeEditing;

  bool isEditingFlow = false;
  bool isSinking = false;
  var selectedMode = EditorModes.view;

  final crdtBufferController = StreamController<ExposedCRDTPayload>();
  late final crdtBuffer = StreamQueue(crdtBufferController.stream);

  final SyncModelExecutor executor;
  StreamSubscription<SPFrame>? _centrifugoSubscription;

  final processEventQueue = AsyncQueue();

  get isLocalOnly => syncModel.isLocal;

  EditorPageVm(this.syncModel, this.executor);

  void init(BuildContext context) {
    switch (syncModel.isLocal) {
      case true:
        _localInit();
      case false:
        _networkInit(context);
    }
  }

  void _localInit() {
    mdEditor.text = EditorAutomergeUtils.instance.toText(
      syncModel.document.automergeDoc,
    );
    notifyListeners();
  }

  Future<void> _networkInit(BuildContext context) async {
    syncModel.document.automergeDoc.setActorId(
      uuid: AccountSecureStorage.instance.account.actorId,
    );

    processEventQueue.addQueueListener((e) {
      logger.i('Queue listener: ${e.currentQueueSize}');
      isSinking = !(e.currentQueueSize == 0);
      notifyListeners();
    });

    mdEditor.text = EditorAutomergeUtils.instance.toText(
      syncModel.document.automergeDoc,
    );
    notifyListeners();

    // ---- Init buffer
    var initialBuffer = true;
    final initialCentrifugoBuffer = [];

    _changeManager.stream(executor.syncModel.document.id).listen((
      spFrame,
    ) async {
      initialCentrifugoBuffer.add(spFrame);

      if (!initialBuffer) {
        for (final frame in initialCentrifugoBuffer) {
          processEventQueue.addJob(() => processFrame(context, frame));
        }
        initialCentrifugoBuffer.clear();
        await processEventQueue.start();
      }
    });

    final frames = _changeManager.getFrames(executor.syncModel.document.id);
    for (final frame in frames.values) {
      processEventQueue.addJob(() => processFrame(context, frame));
    }
    await processEventQueue.start();

    initialBuffer = false;
  }

  // ---
  Future<void> processFrame(BuildContext context, SPFrame frame) async {
    try {
      final (crdtPayloadList, isCurrentUser) = await executor.processFrame(
        frame,
      );

      if (isCurrentUser) {
        logger.i('Received frame sent by current user, omitting...');
        return;
      }

      logger.i('Processing incoming frame...');

      for (final payload in crdtPayloadList) {
        crdtBufferController.add(payload);
      }

      if (selectedMode != EditorModes.edit) {
        final crdtPayloads = await loadBuffer();
        if (crdtPayloads.isEmpty) {
          return;
        }

        mdEditor.text = await executor.appyCrdtOperation(crdtPayloads);

        hashBeforeEditing(mdEditor.text);

        logger.i(
          'Document state after sync ${syncModel.document.automergeDoc.getBlocks()}',
        );

        notifyListeners();
      }
    } catch (e) {
      if (e.toString().contains('User removed from group')) {
        // ignore: use_build_context_synchronously
        await _handleRemoveMember(context);
      } else {
        logger.e('Error processing frame: $e');
      }
    }
  }

  // --- INIT ---

  Future<void> _handleRemoveMember(BuildContext context) async {
    logger.i('User removed from group, adding as local');

    await executor.makeLocalOperation();
    await selectMode(EditorModes.view);
    await _centrifugoSubscription?.cancel();
    notifyListeners();

    if (!context.mounted) return;
    TopBanner.show(
      context: context,
      message: 'You have been removed from the group',
      kind: TopBannerCases.info,
    );
  }

  Future<void> selectMode(EditorModes mode) async {
    final runSync =
        selectedMode == EditorModes.edit && mode == EditorModes.view;

    if (runSync) {
      await editorTextSynchronize();
    }

    selectedMode = mode;

    notifyListeners();
  }

  Future<void> editorTextSynchronize() async {
    var hashAfterEditing = sha256
        .convert(utf8.encode(mdEditor.text))
        .toString();

    if (_hashBeforeEditing != hashAfterEditing) {
      logger.i('Uploading new changes..');

      final crdtPayloadList = await loadBuffer();
      await executor.sendFrame(mdEditor.text, crdtPayloadList);
      hashBeforeEditing(mdEditor.text);

      logger.i(
        'Document state after changing mode ${syncModel.document.automergeDoc.getBlocks()}',
      );
    } else {
      final crdtPayloadList = await loadBuffer();

      if (crdtPayloadList.isNotEmpty) {
        logger.i('Syncing buffered changes..');

        mdEditor.text = await executor.appyCrdtOperation(crdtPayloadList);

        hashBeforeEditing(mdEditor.text);
      } else {
        logger.i('No buffered changes, no local changes, nothing to sync');
      }
    }

    isSinking = false;
    notifyListeners();
  }

  Future<List<ExposedCRDTPayload>> loadBuffer() async {
    final buffer = <ExposedCRDTPayload>[];

    while (await crdtBuffer.hasNext.timeout(
      Durations.short3,
      onTimeout: () => false,
    )) {
      buffer.add(await crdtBuffer.next);
    }
    return buffer;
  }

  void hashBeforeEditing(String text) {
    _hashBeforeEditing = sha256.convert(utf8.encode(text)).toString();
  }

  void editMD() {
    notifyListeners();
  }

  Future<List<MemberScreenModel>> prepareMembers() async {
    final groupInfo = syncModel.groupContext.retrieveGroupInfo();

    final members = groupInfo.members
        .map(
          (e) => MemberScreenModel(
            member: DocumentMember(
              account: ExternalAccount(
                actorId: e.id,
                name: e.name,
                rawPublicKey: e.publicKey,
              ),
              role: e.role.value,
              roleName: e.role.name,
            ),
            isYou: AccountSecureStorage.instance.account.actorId == e.id,
            isOwner: e.role.value == ownerRole,
          ),
        )
        .where((e) => e.member.account.name != 'Invited')
        .toList();

    return members;
  }

  List<ChangeEvent> prepareChanges() {
    final members = syncModel.groupContext.retrieveGroupInfo().members;

    return syncModel.document.automergeDoc
        .getChangeList()
        .indexed
        .map(
          (e) => ChangeEvent(
            title: 'Change',
            actorIdHex: e.$2.actorIdHex(),
            changeHashHex: e.$2.changeHash(),
            date: e.$2.timestamp(),
            name:
                members
                    .firstWhereOrNull((elem) => elem.id == e.$2.actorIdHex())
                    ?.name ??
                e.$2.actorIdHex(),
            isInitial: e.$1 == 0,
          ),
        )
        .toList()
        .reversed
        .toList();
  }

  @override
  void dispose() async {
    _centrifugoSubscription?.cancel();

    final crdtPayloadList = await loadBuffer();
    if (crdtPayloadList.isNotEmpty) {
      await executor.appyCrdtOperation(crdtPayloadList);
    }

    await DB.instance.updateDocument(
      doc: syncModel.document,
      parts: syncModel.groupContext.asParts(),
    );
    super.dispose();
  }
}
