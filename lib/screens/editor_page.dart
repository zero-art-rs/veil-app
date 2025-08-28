import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:zk_notion_app/managers/document_storage.dart' as storage;
import 'package:zk_notion_app/screens/history_page.dart';
import 'package:zk_notion_app/utils/appflowy.dart';

class _EditorPageState extends State<EditorPage> {
  late final EditorState _editorState;

  late final StreamSubscription<(TransactionTime, Transaction, ApplyOptions)>
  _txListener;

  late final Timer _saveTicker;

  @override
  void initState() {
    final blocs = widget.doc.content.getBlocks();

    print(widget.doc.content.info());
    print('blocks empty: ${blocs.isEmpty}');

    if (blocs.isNotEmpty) {
      _editorState = EditorState(
        document: Document.fromJson(
          FlowyUtils.automerge2Flowy(widget.doc.content),
        ),
      );
    } else {
      widget.doc.content.insertBlock(index: BigInt.from(0), text: '');
      _editorState = EditorState.blank();
    }

    setupAutomergeDocSync();
    setupSaveDocTicker();
    super.initState();
  }

  setupSaveDocTicker() {
    _saveTicker = Timer.periodic(const Duration(seconds: 3), (timer) {
      saveAutomergeDoc();
    });
  }

  saveAutomergeDoc() {
    widget.doc.content.saveIncremental();
  }

  setupAutomergeDocSync() {
    _txListener = _editorState.transactionStream.listen((event) {
      final (time, transaction, options) = event;
      if (time == TransactionTime.before) return;
      for (final op in transaction.operations) {
        try {
          final opDetails = op.toJson();
          final blockNum = int.parse(opDetails['path'][0].toString());
          print(opDetails);

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
          print(err.toString());
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
    saveAutomergeDoc();
    widget._storage.updateDocument(widget.doc);
    super.dispose();
  }
}

class EditorPage extends StatefulWidget {
  final storage.Document doc;
  final _storage = storage.DocumentStorage();
  EditorPage({super.key, required this.doc});

  @override
  State<EditorPage> createState() => _EditorPageState();
}
