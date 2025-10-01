import 'dart:convert';

import 'package:veil/managers/sharing/spk_manager.dart';

class QrUtils {
  static final instance = QrUtils();

  String buildShareContactData(SharedSpkRevealData payload) {
    return jsonEncode(payload.toJson());
  }

  SharedSpkRevealData parseShareContactData(String data) {
    return SharedSpkRevealData.fromJson(jsonDecode(data));
  }
}
