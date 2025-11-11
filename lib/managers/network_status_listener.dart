import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/subjects.dart';
import 'package:veil/main.dart';

enum NetworkStatus { connectedServiceUnavailable, disconnected, connected }

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
    _networkLookupTicker = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        final stopwatch = Stopwatch()..start();

        final uri = Uri.parse('https://veil.distributedlab.com/health');

        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 2));

        final slow =
            stopwatch.elapsedMilliseconds >=
            Durations.extralong2.inMilliseconds;

        if (slow) {
          logger.w('Network lookup took ${stopwatch.elapsedMilliseconds}ms');
        }

        final serviceAvaliable = response.statusCode == 200;

        connectionStatus.add(
          !slow && serviceAvaliable
              ? NetworkStatus.connected
              : NetworkStatus.connectedServiceUnavailable,
        );
      } catch (e) {
        if (!timer.isActive) return;
        logger.e('Failed to check network status: $e');
        connectionStatus.add(NetworkStatus.connectedServiceUnavailable);
      }
    });
  }

  void dispose() {
    _connectionListener.cancel();
    _networkLookupTicker?.cancel();
  }
}
