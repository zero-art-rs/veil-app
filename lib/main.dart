import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:veil/assets/util.dart';
import 'package:veil/managers/deeplink_manager.dart';
import 'package:veil/managers/invite_manager.dart';
import 'package:veil/managers/sync_provider/sync_provider.dart';
import 'package:veil/screens/desktop/primary_page.dart';
import 'package:veil/screens/desktop/primary_page_vm.dart';
import 'package:veil/screens/docs_page/docs_page.dart';
import 'package:veil/screens/docs_page/docs_page_vm.dart';
import 'package:veil/screens/tab_bar.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/src/rust/frb_generated.dart';
import 'package:veil/assets/theme.dart';
import 'package:logger/logger.dart';
import 'package:app_links/app_links.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/widgets/banner.dart';
import 'package:veil/utils/platform.dart';
import 'package:veil/widgets/future_dialog.dart';

Future<void> main() async {
  await RustLib.init();
  initTracing();

  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppSecureStorage.instance.setAccountIfNeeded();
    await DB.instance.open();
    // DB.instance.removeAll();
    logger.d('Db path: ${await getDatabasesPath()}');
    await SyncProvider.instance.init();
  } catch (e) {
    logger.e('Launch app error: $e');
  }
  runApp(MyApp());
}

var logger = Logger(
  filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
  printer: PrettyPrinter(
    noBoxingByDefault: true,
    dateTimeFormat: DateTimeFormat.dateAndTime,
  ),
  level: Level.all,
);
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
    _listenUriChanges();
  }

  @override
  void dispose() {
    logger.d('My app dispose called');
    _sub?.cancel();
    super.dispose();
  }

  void _listenUriChanges() {
    if (!PlatformUtils.isApple) return;
    try {
      _sub = _appLinks.uriLinkStream.listen(
        (Uri? uri) {
          final (documentDeepLink, contactDeepLink) = DeeplinkManager()
              .retrieveDeepLink(uri);

          if (contactDeepLink != null && mounted) {
            _showContactPopUp(navigatorKey.currentContext!, contactDeepLink);
            return;
          }

          if (documentDeepLink != null && mounted) {
            _showDocumentInvitationPopUp(
              navigatorKey.currentContext!,
              documentDeepLink.inviteData,
            );
            return;
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

  void _showDocumentInvitationPopUp(
    BuildContext context,
    String inviteData,
  ) async {
    await showFutureDialog(
      title: 'Invitation',
      context: context,
      work: () async => await _acceptInvite(context, inviteData),
      applyText: 'Join',
      cancelText: 'Cancel',
      message: 'You have been invited to join the document.',
      successTitle: 'Success',
      successMessage: 'You have joined the document.',
    );
  }

  Future<void> _acceptInvite(BuildContext context, String inviteData) async {
    final account = await AppSecureStorage.instance.getAccount();

    if (account == null) {
      throw Exception('No account, unreachable flow');
    }

    final (pendingGroupContext, document) = await InviteManager.instance.join(
      inviteData,
    );

    // make pending add
    await SyncProvider.instance.addFromInvite(
      document,
      pendingGroupContext,
      user: BUser(name: account.name, publicKey: account.keypair.rawPublicKey),
    );

    if (!context.mounted) return;
    Navigator.pop(context);
  }

  void _showContactPopUp(BuildContext context, ExternalAccount account) {
    final th = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: BoxBorder.all(color: Colors.grey, width: 0.3),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name', style: th.labelLarge),
                    Text(
                      account.name,
                      style: th.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 12),

                    Text('Actor ID', style: th.labelLarge),
                    Text(
                      account.actorId,
                      style: th.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 12),

                    Text('Public Key', style: th.labelLarge),
                    Text(
                      account.publicKey,
                      style: th.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            Text(
              'Add this account to your contacts?',
              style: th.bodyLarge,
              textAlign: TextAlign.center,
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
                  onPressed: () async {
                    try {
                      await DB.instance.insertContact(account);
                    } on DatabaseException catch (e) {
                      if (!context.mounted) return;

                      if (e.isUniqueConstraintError()) {
                        TopBanner.show(
                          context: context,
                          message: 'Account already in your contacts',
                          kind: TopBannerCases.info,
                        );
                      } else {
                        TopBanner.show(
                          context: context,
                          message: 'Unexpected error, try again',
                          kind: TopBannerCases.error,
                        );

                        logger.e('Failed to add contact: $e');
                      }
                    } catch (e) {
                      if (!context.mounted) return;

                      logger.e('Failed to add contact: $e');
                      TopBanner.show(
                        context: context,
                        message: 'Something went wrong, try again',
                        kind: TopBannerCases.error,
                      );
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: Text('Add'),
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
    TextTheme textTheme = createTextTheme(context, "Roboto", "Urbanist");
    MaterialTheme theme = MaterialTheme(textTheme);

    return MaterialApp(
      localizationsDelegates: const [],
      theme: theme.dark(),
      themeMode: ThemeMode.dark,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => PrimaryPageViewModel(),
            child: DesktopPrimaryPage(),
          ),
          ChangeNotifierProvider(
            create: (_) => DocsPageViewModel()..sink(),
            child: DocsPage(),
          ),
        ],
        child: PlatformUtils.isDesktop
            ? DesktopPrimaryPage()
            : AppBottomTabBar(),
      ),
      navigatorKey: navigatorKey,
    );
  }
}
