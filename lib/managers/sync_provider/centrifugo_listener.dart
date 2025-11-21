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
  final _disconnectedEventController = StreamController<bool>();
  Stream<bool> get disconnectedEvent => _disconnectedEventController.stream;
  var _disconnected = false;

  CentrifugoListener({required dynamic Function(EventFluxData) processCallback})
    : _processCallback = processCallback;

  void connect(String jwtToken) {
    _eventFlux.connect(
      EventFluxConnectionType.get,
      '$_url/connection/uni_sse?cf_connect={"token": "$jwtToken"}',
      onSuccessCallback: (response) {
        logger.info('Centrifugo connection established');
        _centrifugoListener = response?.stream?.listen((data) {
          if (_disconnected) return;
          _lastEventTime = DateTime.now();
          _processCallback(data);
        });
      },
      onConnectionClose: () async {
        logger.info('Connection with Centrifugo closed');
        await _disconnect();
      },
      onError: (error) async {
        logger.error(
          'Centrifugo error: ${error.message}, reason: ${error.reasonPhrase}, status: ${error.statusCode}',
        );

        await _disconnect();
      },
    );

    _runConnectionChecker();
  }

  /// Closes the connection with Centrifugo, sends disconnected event
  Future<void> _disconnect() async {
    _disconnected = true;
    _disconnectedEventController.add(true);
    _connectionChecker?.cancel();
    await _eventFlux.disconnect();
    await _disconnectedEventController.close();
    await _centrifugoListener?.cancel();
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

      await _disconnect();
    }
  }

  /// Closes the connection with Centrifugo
  Future<void> dispose() async {
    _disconnected = true;
    _connectionChecker?.cancel();
    await _eventFlux.disconnect();
    logger.info('Centrifugo connection closed');
  }
}
