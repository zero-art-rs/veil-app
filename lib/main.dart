import 'package:flutter/material.dart';
import 'package:zk_notion_app/components/member_cell.dart';
import 'package:zk_notion_app/screens/docs_page.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:zk_notion_app/src/rust/frb_generated.dart';
import 'package:zk_notion_app/theme.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final doc = BAutoCommit();
    doc.putRootObject(label: "root", value: BObjType.list);
    final docBytes = doc.save();

    return MaterialApp(
      theme: AppTheme.light(),
      themeMode: ThemeMode.system,
      home: DocsUiOnlyPage()
    );
  }
}
