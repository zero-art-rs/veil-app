import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/contacts_manager.dart';
import 'package:veil/managers/sharing/spk_manager.dart';
import 'package:veil/utils/qr.dart';
import 'package:veil/widgets/future_dialog.dart';

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

  void _onDetect(BarcodeCapture capture) {
    if (_processing || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;

    _processing = true;
    HapticFeedback.vibrate();

    try {
      final contactData = QrUtils.instance.parseShareContactData(code);
      _showContactPopUp(
        context,
        contactData,
        () => Future.delayed(Duration(seconds: 1), () => _processing = false),
      );
    } catch (err) {
      logger.e('Failed to parse qr code: $err');
      _showErrorDialog(context, 'Failed to parse qr code', () {
        Future.delayed(Duration(seconds: 1), () => _processing = false);
      });
      return;
    }
  }

  void _showContactPopUp(
    BuildContext context,
    SharedSpkRevealData payload,
    void Function()? onSuccessOk,
  ) async {
    await showFutureDialog<SpkShareData>(
      autoStart: true,
      successTitle: 'Contact info',
      context: context,
      dialogSize: Size(480, 240),
      onSuccessOk: onSuccessOk,
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
