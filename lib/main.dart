import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:zk_notion_app/managers/app_storage.dart';
import 'package:zk_notion_app/screens/tab_bar.dart';
import 'package:zk_notion_app/src/rust/frb_generated.dart';
import 'package:zk_notion_app/theme.dart';
import 'package:logger/logger.dart';


Future<void> main() async {
  await RustLib.init();
  runApp(MyApp());
}

var logger = Logger(printer: PrettyPrinter());

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final AppStorage _storage = AppStorage();

  @override
  Widget build(BuildContext context) {
    _storage.getAccount().then((value) {
      if (value == null) {
        _storage.setAccount(
          Account(
            name: 'Test Account',
            actorId: 'd759f0aa-ea3c-419a-b5c2-3853c0202623',
          ),
        );
      }
    });

    return MaterialApp(
      localizationsDelegates: const [AppFlowyEditorLocalizations.delegate],
      theme: AppTheme.light(),
      themeMode: ThemeMode.system,
      home: AppBottomTabBar(),
    );
  }
}
