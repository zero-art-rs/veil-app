import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/storage/account_storage.dart';
import 'package:zk_notion_app/screens/doc_members.dart';
import 'package:zk_notion_app/screens/history_page.dart';
import 'package:zk_notion_app/storage/document_storage.dart';
import 'package:zk_notion_app/storage/models.dart' as models;
import 'package:zk_notion_app/utils/editor_automerge.dart';
import 'package:zk_notion_app/utils/platform.dart';

class _EditorPageState extends State<EditorPage> {
  final _composer = MutableDocumentComposer();
  late Editor _editor = createDefaultDocumentEditor(
    document: MutableDocument.empty(),
    composer: _composer,
  );
  late final Timer _saveTicker;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final account = await widget._accStorage.getAccount();

    if (account == null) {
      logger.f('Account is null, unreachable flow!');
      return;
    }

    widget.doc.automergeDoc.setActorId(uuid: account.actorId);
    widget.doc.automergeDoc.setupBlockLabel();

    final blocks = widget.doc.automergeDoc.getBlocks();
    if (blocks.isNotEmpty) {
      _editor = createDefaultDocumentEditor(
        document: EditorAutomergeUtils.instance.toDoc(widget.doc.automergeDoc),
        composer: _composer,
      );
    }

    _setupCommitTicker();

    if (mounted) setState(() {});
  }

  _setupCommitTicker() {
    _saveTicker = Timer.periodic(const Duration(seconds: 3), (timer) {
      _commit();
    });
  }

  _commit() {
    EditorAutomergeUtils.instance.fromDoc(
      _editor.document,
      widget.doc.automergeDoc,
    );
    widget.doc.automergeDoc.commit();
  }

  Future<List<MemberScreenModel>> _prepareMembers() async {
    final account = await widget._accStorage.getAccount();
    return widget.doc.members
        .map(
          (e) => MemberScreenModel(
            member: e,
            isYou: e.account.actorId == account?.actorId,
          ),
        )
        .toList();
  }

  Widget _memberListButton(BuildContext context) {
    if (widget.isMemberListAccessible) {
      return IconButton(
        icon: const Icon(Icons.group),
        onPressed: () async {
          final members = await _prepareMembers();

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    DocumentMemberListScreen(members: members, doc: widget.doc),
              ),
            );
          }
        },
      );
    } else {
      return Container();
    }
  }

  Widget _historyButton(BuildContext context) {
    if (!widget.isHistoryAccessible) {
      return Container();
    } else {
      return IconButton(
        icon: const Icon(Icons.history),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              _commit();

              final items = widget.doc.automergeDoc
                  .getChangeList()
                  .indexed
                  .map(
                    (e) => ChangeEvent(
                      title: 'Change',
                      actorIdHex: e.$2.actorIdHex(),
                      changeHashHex: e.$2.changeHash(),
                      date: e.$2.timestamp(),
                      isInitial: e.$1 == 0,
                    ),
                  )
                  .toList()
                  .reversed
                  .toList();

              return HistoryPage(items: items, doc: widget.doc);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SuperEditor(
      focusNode: _focus,
      editor: _editor,
    );
  }

  @override
  void dispose() {
    _saveTicker.cancel();
    _commit();
    widget._docStorage.updateDocument(widget.doc);
    logger.d('Deinit editor screen');

    super.dispose();
  }
}

class EditorPage extends StatefulWidget {
  final models.Document doc;
  final _docStorage = DocumentStorage();
  final _accStorage = AccountStorage();
  final bool isMemberListAccessible;
  final bool isHistoryAccessible;
  final bool readOnly;

  EditorPage({
    super.key,
    required this.doc,
    this.isMemberListAccessible = true,
    this.isHistoryAccessible = true,
    this.readOnly = false,
  });

  @override
  State<EditorPage> createState() => _EditorPageState();
}
