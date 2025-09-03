import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/storage/contact_storage.dart';
import 'package:zk_notion_app/storage/models.dart';
import 'package:zk_notion_app/utils/banner.dart';
import 'package:zk_notion_app/widgets/user_widget.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  final _storage = ContactStorage.shared;
  bool _processing = false;

  Future<void> _showErrorDialog(
    BuildContext context,
    String message,
    Function callback,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              callback();
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAccountDialog(
    BuildContext context,
    ExternalAccount account,
    VoidCallback onAdd,
    VoidCallback onCancel,
  ) async {
    return showDialog(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: UserInfoView(
            info: UserInfo(
              name: account.name,
              actorId: account.actorId,
              publicKey: account.publicKey,
            ),
            onAdd: onAdd,
            onCancel: onCancel,
          ),
        );
      },
    );
  }

  _addContact(ExternalAccount account, BuildContext context) async {
    final navigator = Navigator.of(context);
    try {
      final duplicate = await _storage.addContact(account: account);

      if (duplicate && context.mounted) {
        TopBanner.show(
          context: context,
          message: 'Contact already exists',
          kind: TopBannerCases.info,
        );
      }

      if (!duplicate && context.mounted) {
        TopBanner.show(
          context: context,
          message: 'Contact added',
          kind: TopBannerCases.success,
        );
      }

      Timer(const Duration(seconds: 1), () {
        _processing = false;
      });

      navigator.pop();
    } catch (err) {
      logger.e('Failed to add contact: $err');

      if (context.mounted) {
        _showErrorDialog(context, 'Failed to add contact', () {
          Future.delayed(const Duration(seconds: 1), () {
            _processing = false;
          });
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;

    _processing = true;
    HapticFeedback.vibrate();

    try {
      final json = jsonDecode(code);
      final account = ExternalAccount.fromJson(json);
      _showAccountDialog(
        context,
        account,
        () async => await _addContact(account, context),
        () {
          Future.delayed(const Duration(seconds: 1), () {
            _processing = false;
          });
          Navigator.of(context).pop();
        },
      );
    } catch (err) {
      logger.e('Invalid QR code: $err');

      _showErrorDialog(context, 'Invalid QR code', () {
        Future.delayed(const Duration(seconds: 1), () {
          _processing = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const double _windowSize = 260;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: LayoutBuilder(
        builder: (context, c) {
          final scanRect = Rect.fromCenter(
            center: Offset(c.maxWidth / 2, c.maxHeight / 2),
            width: _windowSize,
            height: _windowSize,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                fit: BoxFit.cover,
                scanWindow: scanRect,
                onDetect: _onDetect,
              ),
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: _windowSize,
                    height: _windowSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
