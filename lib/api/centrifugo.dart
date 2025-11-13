import 'dart:async';

import 'package:eventflux/eventflux.dart';
import 'package:veil/main.dart';

class CentrifugoListener {
  final _url = 'https://sse-veil.distributedlab.com';
  final eventFlux = EventFlux.spawn();
  dynamic Function(EventFluxData) streamCallback;
  dynamic Function()? onConnectionClose;
  dynamic Function(EventFluxException)? onError;

  StreamSubscription<dynamic>? _listener;

  CentrifugoListener({required this.streamCallback, this.onError});

  Future<void> connect(String jwtToken) async {
    eventFlux.connect(
      EventFluxConnectionType.get,
      '$_url/connection/uni_sse?cf_connect={"token": "$jwtToken"}',
      onSuccessCallback: (response) {
        logger.info('Centrifugo connection established');
        _listener = response?.stream?.listen((data) {
          streamCallback(data);
        });
      },
      onConnectionClose: () {
        logger.info('Centrifugo connection closed by server');
        onConnectionClose?.call();
      },
      onError: (error) async {
        logger.error(
          'Centrifugo error: ${error.message}, reason: ${error.reasonPhrase}, status: ${error.statusCode}',
        );

        await disconnect();

        onError?.call(error);
      },
    );
  }

  Future<void> disconnect() async {
    await eventFlux.disconnect();
    await _listener?.cancel();
    logger.info('Centrifugo connection closed');
  }
}
