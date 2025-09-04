import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:zk_notion_app/screens/tab_bar.dart';
import 'package:zk_notion_app/src/rust/frb_generated.dart';
import 'package:zk_notion_app/storage/document_storage.dart';
import 'package:zk_notion_app/theme.dart';
import 'package:logger/logger.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(MyApp());
}

var logger = Logger(printer: PrettyPrinter());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [AppFlowyEditorLocalizations.delegate],
      theme: AppTheme.light(),
      themeMode: ThemeMode.system,
      home: AppBottomTabBar(),
    );
  }
}
