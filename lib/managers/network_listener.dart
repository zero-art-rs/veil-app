import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/subjects.dart';
import 'package:veil/main.dart';

class NetworkListener {
  static final NetworkListener instance = NetworkListener._internal();
  BehaviorSubject<bool> isConnected = BehaviorSubject.seeded(true);
  late Timer _networkLookupTicker;
  late StreamSubscription<List<ConnectivityResult>> _connectionListener;

  NetworkListener._internal();

  void start() {
    _connectionListener = Connectivity().onConnectivityChanged.listen((result) {
      final interestedConnections = {
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
        ConnectivityResult.ethernet,
      };

      final containsConnection = result.any(
        (element) => interestedConnections.contains(element),
      );

      if (!containsConnection) {
        isConnected.add(false);
        _networkLookupTicker.cancel();
      } else if (containsConnection && !_networkLookupTicker.isActive) {
        _initLookupTicker();
      }
    });
  }

  void _initLookupTicker() {
    _networkLookupTicker = Timer.periodic(Duration(seconds: 3), (timer) async {
      try {
        final stopwatch = Stopwatch()..start();

        final uri = Uri.parse('https://veil.distributedlab.com/health');
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 2));

        final slow =
            stopwatch.elapsedMilliseconds >= Durations.long1.inMilliseconds;

        final serviceAvaliable = response.statusCode == 200;

        isConnected.add(!slow && serviceAvaliable);
      } catch (e) {
        logger.e('Failed to check network status: $e');
        isConnected.add(false);
      }
    });
  }

  void dispose() {
    _connectionListener.cancel();
    _networkLookupTicker.cancel();
  }
}
