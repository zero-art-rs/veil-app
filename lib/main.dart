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
import 'package:app_links/app_links.dart';
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
  final AppLinks _appLinks = AppLinks();

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
    if (!PlatformUtils.isApple) return;
    try {
      final Uri? initialUri = await AppLinks().getInitialLink();
      if (initialUri != null && mounted) {
        logger.d('Initial uri: $initialUri');
        _showPopUp(navigatorKey.currentContext!);
      }
    } catch (err) {
      logger.e('Failed to get initial link: $err');
    }
  }

  void _listenUriChanges() {
    if (!PlatformUtils.isApple) return;
    try {
      _sub = _appLinks.uriLinkStream.listen(
        (Uri? uri) {
          if (uri != null && mounted) {
            logger.d('Uri changed: $uri');
            _showPopUp(navigatorKey.currentContext!);
          }
        },
        onDone: () => logger.d('Uri stream done'),
        onError: (err) {
          logger.e('Failed to get uri: $err');
        },
      );
    } catch (err) {
      logger.e('Failed to get uri: $err');
    }
  }

  void _showPopUp(BuildContext context) {
    final th = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description, size: 92),
            const SizedBox(height: 32),
            Text(
              'You have been invited to the document, do you want to join?',
              style: th.bodyLarge,
            ),
          ],
        ),
        actions: [
          const SizedBox(height: 24),
          Row(
            spacing: 16.0,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
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
