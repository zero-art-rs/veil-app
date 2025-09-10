import 'dart:async';

// import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zk_notion_app/assets/style.dart';
import 'package:zk_notion_app/assets/util.dart';
import 'package:zk_notion_app/screens/desktop/primary_page.dart';
import 'package:zk_notion_app/screens/desktop/primary_page_vm.dart';
import 'package:zk_notion_app/screens/tab_bar.dart';
import 'package:zk_notion_app/src/rust/frb_generated.dart';
import 'package:zk_notion_app/assets/theme.dart';
import 'package:logger/logger.dart';
import 'package:uni_links/uni_links.dart';
import 'package:zk_notion_app/utils/banner.dart';
import 'package:zk_notion_app/utils/platform.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(MyApp());
}

var logger = Logger(printer: PrettyPrinter());
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _handleInitialUri();
    _listenUriChanges();
  }

  @override
  void dispose() {
    logger.d('My app dispose called');
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handleInitialUri() async {
    if (PlatformUtils.isDesktop) return;
    try {
      final Uri? initialUri = await getInitialUri();
      if (initialUri != null && mounted) {
        _showPopUp(navigatorKey.currentContext!);
      }
    } catch (err) {
      logger.e('Failed to get initial link: $err');
    }
  }

  void _listenUriChanges() {
    if (PlatformUtils.isDesktop) return;
    _sub = uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null && mounted) {
          _showPopUp(navigatorKey.currentContext!);
        }
      },
      onError: (err) {
        logger.e('Failed to get uri: $err');
      },
    );
  }

  void _showPopUp(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Center(
        child: Container(
          height: 300,
          width: 300,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.description, size: 92),

              Spacer(),

              Text(
                'You have been invited to the document, do you want to join?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  decoration: TextDecoration.none,
                ),
              ),

              Spacer(),

              Row(
                spacing: 16.0,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: AppStyles.lightErrorButtonStyle,
                      child: Text('Cancel'),
                    ),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Join'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = View.of(context).platformDispatcher.platformBrightness;
    TextTheme textTheme = createTextTheme(context, "Roboto", "Urbanist");
    MaterialTheme theme = MaterialTheme(textTheme);

    return MaterialApp(
      localizationsDelegates: const [],
      theme: brightness == Brightness.light ? theme.light() : theme.dark(),
      themeMode: ThemeMode.dark,
      home: PlatformUtils.isDesktop
          ? ChangeNotifierProvider(
              create: (_) => PrimaryPageViewModel(),
              child: DesktopPrimaryPage(),
            )
          : const AppBottomTabBar(),
      navigatorKey: navigatorKey,
    );
  }
}
