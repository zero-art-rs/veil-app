import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:veil/assets/util.dart';
import 'package:veil/managers/contacts_manager.dart';
import 'package:veil/managers/invite_manager.dart';
import 'package:veil/managers/sharing/deeplink_manager.dart';
import 'package:veil/managers/sharing/spk_manager.dart';
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
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/platform.dart';
import 'package:veil/widgets/future_dialog.dart';

Future<void> main() async {
  await RustLib.init();
  initTracing();

  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppSecureStorage.instance.setAccountIfNeeded();
    await DB.instance.open();
    // await DB.instance.removeAll();
    await SyncProvider.instance.init();
    await ContactsManager.instance.setup();
    logger.d('Db path: ${await getDatabasesPath()}');
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
          final (documentDeepLink, contactDeepLink) = DeeplinkManager.instance
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
      work: () async {
        try {
          await _acceptInvite(context, inviteData);
        } catch (err) {
          logger.e('Failed to join document: $err');
          if (err is DioException) {
            if (err.response?.statusCode == 401) {
              throw FutureDialogError('Error', 'No document found');
            }
          }

          throw FutureDialogError('Error', 'Failed to join document');
        }
      },
      applyText: 'Join',
      cancelText: 'Cancel',
      message: 'You have been invited to join the document.',
      successTitle: 'Success',
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

    await SyncProvider.instance.addFromInvite(
      document,
      pendingGroupContext,
      user: BUser(name: account.name, publicKey: account.keypair.rawPublicKey),
    );

    if (!context.mounted) return;
    Navigator.pop(context);
  }

  void _showContactPopUp(
    BuildContext context,
    SharedSpkRevealData payload,
  ) async {
    await showFutureDialog<SpkShareData>(
      autoStart: true,
      successTitle: 'Contact info',
      context: context,
      dialogSize: Size(480, 240),
      work: () async {
        try {
          final spk = await SpkManager.instance.getSpk(payload);
          await ContactsManager.instance.addContact(spk);
          return spk;
        } catch (err) {
          logger.e('Failed to get spk: $err');

          if (err is DioException) {
            if (err.response?.statusCode == 404) {
              throw FutureDialogError('Error', 'Contact share link expired');
            }
          }

          throw FutureDialogError(
            'Error',
            'Failed to receive info about contact',
          );
        }
      },
      successBuilder: (spk) {
        final th = Theme.of(context).textTheme;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey, width: 0.3),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name', style: th.labelLarge),
                    Text(
                      spk.account.name,
                      style: th.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 12),

                    Text('Actor ID', style: th.labelLarge),
                    Text(
                      spk.account.actorId,
                      style: th.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 12),

                    Text('Public Key', style: th.labelLarge),
                    Text(
                      spk.account.publicKey,
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
              'Added to your contacts',
              style: th.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
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
