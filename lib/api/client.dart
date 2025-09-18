import 'dart:typed_data';

import 'package:http/http.dart' as http;

class GroupApiClient {
  final String baseUrl = 'https://veil.distributedlab.com';
  final http.Client _http = http.Client();

  static final instance = GroupApiClient();

  Future<void> sendFrame({
    required String groupId,
    required Uint8List frame,
  }) async {
    final url = Uri.parse('$baseUrl/v1/group/$groupId/frames');

    final response = await _http.post(
      url,
      headers: {'Content-Type': 'application/protobuf'},
      body: frame,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to send frame: ${response.statusCode} ${response.body}',
      );
    }
  }
}
