import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/subjects.dart';
import 'package:veil/main.dart';

enum NetworkStatus { connectedServiceUnavailable, disconnected, connected }

class _ServicesStatusResponse {
  final bool node;
  final bool centrifugo;
  final bool nats;
  final bool storage;
  final bool relay;

  _ServicesStatusResponse({
    required this.node,
    required this.centrifugo,
    required this.nats,
    required this.relay,
    required this.storage,
  });

  factory _ServicesStatusResponse.fromJson(Map<String, dynamic> json) {
    return _ServicesStatusResponse(
      node: json['node'],
      centrifugo: json['centrifugo'],
      nats: json['nats'],
      storage: json['storage'],
      relay: json['relay'],
    );
  }

  void logStatuses() {
    final msg =
        'Services status. '
        'Node: $node, '
        'Relay: $relay, '
        'Centrifugo: $centrifugo, '
        'Nats: $nats, '
        'Storage: $storage';

    if (!isServiceAvaliable()) {
      logger.error(msg);
    } else {
      logger.debug(msg);
    }
  }

  bool isServiceAvaliable() {
    return node && relay && centrifugo && nats && storage;
  }
}

class NetworkStatusListener {
  static final NetworkStatusListener instance =
      NetworkStatusListener._internal();
  BehaviorSubject<NetworkStatus> connectionStatus = BehaviorSubject.seeded(
    NetworkStatus.connected,
  );
  Timer? _networkLookupTicker;
  late StreamSubscription<List<ConnectivityResult>> _connectionListener;

  NetworkStatusListener._internal();

  void start() {
    _connectionListener = Connectivity().onConnectivityChanged.skip(1).listen((
      result,
    ) {
      final interestedConnections = {
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
        ConnectivityResult.ethernet,
      };

      final containsConnection = result.any(
        (element) => interestedConnections.contains(element),
      );

      if (!containsConnection) {
        connectionStatus.add(NetworkStatus.disconnected);
        _networkLookupTicker?.cancel();
        _networkLookupTicker = null;
      } else if (containsConnection && _networkLookupTicker == null) {
        _initLookupTicker();
      }
    });
  }

  void _initLookupTicker() {
    _networkLookupTicker = Timer.periodic(Duration(seconds: 10), (timer) async {
      try {
        final stopwatch = Stopwatch()..start();

        final uri = Uri.parse(
          'https://veil.distributedlab.com/services/health',
        );

        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 5));

        final servicesStatusList = _ServicesStatusResponse.fromJson(
          jsonDecode(response.body),
        );

        servicesStatusList.logStatuses();

        final slow = stopwatch.elapsedMilliseconds >= 3 * 1000;

        if (slow) {
          logger.warning(
            'Network lookup took ${stopwatch.elapsedMilliseconds}ms',
          );
        }
        ;
        connectionStatus.add(
          !slow && servicesStatusList.isServiceAvaliable()
              ? NetworkStatus.connected
              : NetworkStatus.connectedServiceUnavailable,
        );
      } catch (e) {
        if (!timer.isActive) return;
        logger.warning('Failed to check network status: $e');
        connectionStatus.add(NetworkStatus.connectedServiceUnavailable);
      }
    });
  }

  void dispose() {
    _connectionListener.cancel();
    _networkLookupTicker?.cancel();
  }
}
