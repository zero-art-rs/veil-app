import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:veil/assets/util.dart';
import 'package:veil/managers/contacts_manager.dart';
import 'package:veil/managers/svces_status_listener.dart';
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
import 'package:app_links/app_links.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/platform.dart';
import 'package:veil/widgets/future_dialog.dart';
import 'package:veil/widgets/network_status_banner.dart';

late final Talker logger;

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    logger = Talker();
    await RustLib.init();
    initTracing();
    NetworkStatusListener.instance.start();
    await Hive.initFlutter();
    await AccountSecureStorage.instance.init();
    await DB.instance.open();
    // await DB.instance.removeAll();
    await SyncProvider.instance.init();
    await ContactsManager.instance.setup();
    runApp(MyApp());
  } catch (e, st) {
    logger.error('Launch app error', e, st);
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _sub;
  late final AppLifecycleListener _appLifecycleListener;
  late StreamSubscription<List<ConnectivityResult>> _networkStatusSubscription;

  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _listenUriChanges();
    _listenLifeCycleChanges();
  }

  @override
  void dispose() {
    super.dispose();

    logger.debug('App dispose called');
    _appLifecycleListener.dispose();
    NetworkStatusListener.instance.dispose();
    _networkStatusSubscription.cancel();
    _sub?.cancel();
  }

  void _listenUriChanges() {
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
        onDone: () => logger.debug('Uri stream done'),
        onError: (err, st) {
          logger.error('Failed to get uri', err, st);
        },
      );
    } catch (err, st) {
      logger.error('Failed to get uri', err, st);
    }
  }

  void _listenLifeCycleChanges() {
    // detect sleep
    // resync all the sync models
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
        } catch (err, st) {
          logger.error('Failed to join document', err, st);
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
    final syncModel = await AccountSecureStorage.instance.account.acceptInvite(
      inviteData,
    );

    await SyncProvider.instance.add(
      syncModel,
      insertToDb: true,
      allowFullDocument: true,
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
        } catch (err, st) {
          logger.error('Failed to get spk', err, st);

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
            create: (_) => DocsPageViewModel()..init(),
            child: DocsPage(),
          ),
        ],
        child: Scaffold(
          body: Stack(
            children: [
              PlatformUtils.isDesktop
                  ? DesktopPrimaryPage()
                  : AppBottomTabBar(),

              Align(
                alignment: Alignment.bottomCenter,
                child: NetworkStatusBanner(
                  stream: NetworkStatusListener.instance.connectionStatus,
                ),
              ),
            ],
          ),
        ),
      ),
      navigatorKey: navigatorKey,
    );
  }
}
