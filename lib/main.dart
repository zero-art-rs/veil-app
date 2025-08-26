import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:zk_notion_app/screens/docs_page.dart';
import 'package:zk_notion_app/screens/editor_page.dart';
import 'package:zk_notion_app/src/rust/frb_generated.dart';
import 'package:zk_notion_app/theme.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [AppFlowyEditorLocalizations.delegate],
      theme: AppTheme.light(),
      themeMode: ThemeMode.system,
      home: DocsPage(),
      routes: <String, WidgetBuilder>{'/editor': (context) => EditorPage()},
    );
  }
}
