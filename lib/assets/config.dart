import 'dart:convert';

import 'package:flutter/services.dart';

final _apiBasePathKey = 'api_base_path';
final _sseBasePathKey = 'sse_base_path';
final _monitorBasePathKey = 'monitor_base_path';

class AppConfig {
  String _apiBasePath;
  String _sseBasePath;
  String _monitorBasePath;

  String get apiBasePath => _apiBasePath;
  String get sseBasePath => _sseBasePath;
  String get monitorBasePath => _monitorBasePath;

  static final instance = AppConfig._internal();

  AppConfig._internal({
    String apiBasePath = '',
    String sseBasePath = '',
    String monitorBasePath = '',
  }) : _sseBasePath = sseBasePath,
       _apiBasePath = apiBasePath,
       _monitorBasePath = monitorBasePath;

  Future<void> load() async {
    final config = await () async {
      try {
        return await rootBundle.loadString('assets/config.json');
      } catch (_) {
        return await rootBundle.loadString('assets/config.local.json');
      }
    }();

    final json = jsonDecode(config);
    _monitorBasePath = json[_monitorBasePathKey];
    _apiBasePath = json[_apiBasePathKey];
    _sseBasePath = json[_sseBasePathKey];
  }
}
