import 'dart:async';

import 'package:eventflux/eventflux.dart';
import 'package:veil/main.dart';

const _centrifugoWithoutUpdatesTimeout = 30;

class CentrifugoListener {
  final _url = 'https://sse-veil.distributedlab.com';
  final _eventFlux = EventFlux.spawn();
  final dynamic Function(EventFluxData) _processCallback;
  StreamSubscription<dynamic>? _centrifugoListener;
  DateTime? _lastEventTime;

  Timer? _connectionChecker;
  final _reconnectEventController = StreamController<bool>();
  Stream<bool> get reconnectEvent => _reconnectEventController.stream;
  var _reconnecting = false;

  CentrifugoListener({required dynamic Function(EventFluxData) processCallback})
    : _processCallback = processCallback;

  void connect(String jwtToken) {
    _eventFlux.connect(
      EventFluxConnectionType.get,
      '$_url/connection/uni_sse?cf_connect={"token": "$jwtToken"}',
      onSuccessCallback: (response) {
        logger.info('Centrifugo connection established');
        _centrifugoListener = response?.stream?.listen((data) {
          if (_reconnecting) return;
          _lastEventTime = DateTime.now();
          _processCallback(data);
        });
      },
      onConnectionClose: () async {
        logger.info('Connection with Centrifugo closed');
        await disconnect();
      },
      onError: (error) async {
        logger.error(
          'Centrifugo error: ${error.message}, reason: ${error.reasonPhrase}, status: ${error.statusCode}',
        );

        await disconnect();
      },
    );

    _runConnectionChecker();
  }

  Future<void> disconnect({bool sendReconnectEvent = true}) async {
    if (sendReconnectEvent) {
      _reconnecting = true;
    }

    _reconnectEventController.add(true);
    _connectionChecker?.cancel();
    await _eventFlux.disconnect();

    if (sendReconnectEvent) {
      await _reconnectEventController.close();
      await _centrifugoListener?.cancel();
    }

    logger.info('Centrifugo connection closed');
  }

  void _runConnectionChecker() {
    if (_connectionChecker != null) return;

    _connectionChecker = Timer.periodic(Duration(seconds: 15), (timer) async {
      await _checkCentrifugoConnection();
    });
  }

  Future<void> _checkCentrifugoConnection() async {
    if (_lastEventTime == null) return;

    final now = DateTime.now();
    final difference = now.difference(_lastEventTime!);

    if (difference.inSeconds >= _centrifugoWithoutUpdatesTimeout) {
      logger.warning(
        'No events received from Centrifugo for ${difference.inSeconds} seconds, disconnecting...',
      );

      await disconnect();
    }
  }
}
