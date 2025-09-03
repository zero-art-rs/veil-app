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

  late final StreamSubscription<(TransactionTime, Transaction, ApplyOptions)>
  _txListener;

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

    widget.doc.content.setActorId(uuid: account.actorId);
    widget.doc.content.setupBlockLabel();

    final blocks = widget.doc.content.getBlocks();
    if (blocks.isNotEmpty) {
      _editorState = EditorState(
        document: Document.fromJson(
          FlowyUtils.automerge2Flowy(widget.doc.content),
        ),
      );
    } else {
      widget.doc.content.insertBlock(index: BigInt.zero, text: '');
      _editorState = EditorState.blank();
    }

    _setupAutomergeDocSync();
    _setupCommitTicker();
    _commitAutomergeChanges();

    if (mounted) setState(() {});
  }

  _setupCommitTicker() {
    _saveTicker = Timer.periodic(const Duration(seconds: 6), (timer) {
      logger.d('Commit ticker triggered');
      _commitAutomergeChanges();
    });
  }

  _commitAutomergeChanges() {
    widget.doc.content.commit();
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

  _setupAutomergeDocSync() {
    _txListener = _editorState.transactionStream.listen((event) {
      final (time, transaction, options) = event;
      logger.d("Doc sync event: $event");

      if (time == TransactionTime.before) return;
      for (final op in transaction.operations) {
        try {
          final opDetails = op.toJson();
          final blockNum = int.parse(opDetails['path'][0].toString());

          switch (op.runtimeType) {
            case == InsertOperation:
              widget.doc.content.insertBlock(
                index: BigInt.from(blockNum),
                text: '',
              );
            case == DeleteOperation:
              widget.doc.content.deleteBlock(index: BigInt.from(blockNum));
            case == UpdateOperation:
              final newTextList = opDetails['attributes']['delta'];

              final text = newTextList.isEmpty
                  ? ''
                  : newTextList[0]['insert'].toString();

              widget.doc.content.updateBlock(
                index: BigInt.from(blockNum),
                text: text,
              );
          }
        } catch (err) {
          logger.e('Doc sync error: $err');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doc.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: () async {
              final members = await _prepareMembers();

              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentMemberListScreen(
                      members: members,
                      doc: widget.doc,
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  _commitAutomergeChanges();

                  final items = widget.doc.content
                      .getChangeList()
                      .map(
                        (e) => ChangeEvent(
                          title: 'Change',
                          actorIdHex: e.actorIdHex(),
                          changeHashHex: e.changeHash(),
                          date: e.timestamp(),
                        ),
                      )
                      .toList()
                      .reversed
                      .toList();

                  return HistoryPage(items: items);
                },
              ),
            ),
          ),
        ],
      ),
      body: Container(
        alignment: Alignment.topCenter,
        child: AppFlowyEditor(
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
    _txListener.cancel();
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
  EditorPage({super.key, required this.doc});

  @override
  State<EditorPage> createState() => _EditorPageState();
}
