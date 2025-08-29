import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/managers/app_storage.dart' as storage;
import 'package:zk_notion_app/screens/history_page.dart';
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
    final account = await widget._storage.getAccount();

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

    setupAutomergeDocSync();
    setupCommitTicker();

    commitAutomergeChanges();

    // if (mounted) setState(() {});
  }

  setupCommitTicker() {
    _saveTicker = Timer.periodic(const Duration(seconds: 6), (timer) {
      logger.d('Commit ticker triggered');
      commitAutomergeChanges();
    });
  }

  commitAutomergeChanges() {
    widget.doc.content.commit();
  }

  setupAutomergeDocSync() {
    _txListener = _editorState.transactionStream.listen((event) {
      final (time, transaction, options) = event;
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
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  commitAutomergeChanges();

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
    commitAutomergeChanges();
    widget._storage.updateDocument(widget.doc);

    logger.d('Deinit editor screen');

    super.dispose();
  }
}

class EditorPage extends StatefulWidget {
  final storage.Document doc;
  final _storage = storage.AppStorage();
  EditorPage({super.key, required this.doc});

  @override
  State<EditorPage> createState() => _EditorPageState();
}
