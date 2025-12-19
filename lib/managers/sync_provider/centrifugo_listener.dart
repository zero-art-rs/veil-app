import 'dart:async';

import 'package:eventflux/eventflux.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:veil/assets/config.dart';
import 'package:veil/managers/sync_provider/logger/logger.dart';

const _centrifugoWithoutUpdatesTimeout = 90;

enum CentrifugoConnectionState { success, error }

class CentrifugoListener {
  final _url = AppConfig.instance.sseBasePath;
  final _eventFlux = EventFlux.spawn();
  final SyncModelLogger? logger;
  final dynamic Function(EventFluxData) _processCallback;
  StreamSubscription<dynamic>? _centrifugoListener;
  DateTime? _lastEventTime;

  Timer? _connectionChecker;
  final _disconnectedEventController = StreamController<bool>();
  Stream<bool> get disconnectedEvent => _disconnectedEventController.stream;
  var _disconnected = false;

  CentrifugoListener({
    required dynamic Function(EventFluxData) processCallback,
    required this.logger,
  }) : _processCallback = processCallback;

  void connect(
    String jwtToken, {
    required StreamController<bool> connectionChecker,
  }) {
    _eventFlux.connect(
      EventFluxConnectionType.get,
      '$_url/connection/uni_sse?cf_connect={"token": "$jwtToken"}',
      onSuccessCallback: (response) {
        final isConnected =
            (response?.status == EventFluxStatus.connected ||
            response?.status == EventFluxStatus.connectionInitiated);

        if (!connectionChecker.isClosed) {
          connectionChecker.add(isConnected);
          connectionChecker.close();
        }

        logger?.centrifugoLog('Centrifugo connection established');
        _centrifugoListener = response?.stream?.listen((data) {
          if (_disconnected) return;
          _lastEventTime = DateTime.now();
          _processCallback(data);
        });
      },
      onConnectionClose: () async {
        logger?.centrifugoLog('Connection with Centrifugo closed');
        await _disconnect();
      },
      onError: (error) async {
        logger?.centrifugoLog(
          'Centrifugo error: ${error.message}, reason: ${error.reasonPhrase}, status: ${error.statusCode}',
          level: LogLevel.error,
          stackTrace: StackTrace.current,
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
      logger?.centrifugoLog(
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
    logger?.centrifugoLog('Centrifugo connection closed');
  }
}
