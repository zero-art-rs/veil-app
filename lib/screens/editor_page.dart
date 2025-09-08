import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/storage/account_storage.dart';
import 'package:zk_notion_app/screens/doc_members.dart';
import 'package:zk_notion_app/screens/history_page.dart';
import 'package:zk_notion_app/storage/document_storage.dart';
import 'package:zk_notion_app/storage/models.dart' as models;
import 'package:zk_notion_app/utils/appflowy.dart';

class _EditorPageState extends State<EditorPage> {
  late EditorState _editorState = EditorState.blank();

  // late final StreamSubscription<(TransactionTime, Transaction, ApplyOptions)>
  // _txListener;

  late final Timer _saveTicker;

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
    final html = """<html>
<head>
<title>Page Title</title>
</head>
<body>
<h1>This is a Heading<br /></h1>
<p>This is a paragraph.</p>

<br>
<br>
<br>

<p>This is a rferfparagraph.</p>

</body>
</html>""";
    // print('initial blocks: $blocks');

    // if (blocks.isNotEmpty) {
    _editorState = EditorState(
      document: htmlToDocument(html),
      // document: FlowyUtils.documentFromHtmlAutomerge(widget.doc.automergeDoc),
    );
    // } else {
    // _editorState = EditorState.blank();
    // }

    _setupCommitTicker();

    if (mounted) setState(() {});
  }

  _setupCommitTicker() {
    _saveTicker = Timer.periodic(const Duration(seconds: 3), (timer) {
      _commitAutomergeChanges();
    });
  }

  _commitAutomergeChanges() {
    final html = documentToHTML(_editorState.document);
    FlowyUtils.htmlDoc2Automerge(html, widget.doc.automergeDoc);
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
              _commitAutomergeChanges();

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doc.title),
        actions: [_memberListButton(context), _historyButton(context)],
      ),
      body: Container(
        alignment: Alignment.topCenter,
        child: AppFlowyEditor(
          editable: !widget.readOnly,
          editorState: _editorState,
          editorStyle: EditorStyle.mobile(),
          blockWrapper: (context, {required child, required node}) => Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _saveTicker.cancel();
    _commitAutomergeChanges();
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
