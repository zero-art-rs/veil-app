import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:zk_notion_app/managers/document_storage.dart' as storage;

class _EditorPageState extends State<EditorPage> {
  final editorState = EditorState.blank(withInitialText: true);
  late StreamSubscription<(TransactionTime, Transaction, ApplyOptions)>
  txListener;

  @override
  Widget build(BuildContext context) {
    txListener = editorState.transactionStream.listen((event) {
      final (time, transaction, options) = event;
      if (time == TransactionTime.before) return;
      event.$2.operations.forEach((e) => print(e.toJson()));
    });

    return Scaffold(
      appBar: AppBar(),
      body: Container(
        alignment: Alignment.topCenter,
        child: AppFlowyEditor(
          editorState: editorState,
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
    txListener.cancel();
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
