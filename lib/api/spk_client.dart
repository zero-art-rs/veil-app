import 'dart:convert';

import 'package:http/http.dart' as _http;

class SpkClient {
  static final instance = SpkClient();

  final baseUrl = 'https://veil.distributedlab.com';

  Future<void> sendSPKs({
    required String id,
    required String encryptedBlob,
  }) async {
    final body = {
      'data': {
        'id': id,
        'type': "transfers",
        'attributes': {"data": encryptedBlob},
      },
    };

    final response = await _http.post(
      Uri.parse('$baseUrl/transistor/v1/public/transfers'),
      body: body,
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to post spks: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<String> getSpk(String id) async {
    final response = await _http.get(
      Uri.parse('$baseUrl/transistor/v1/public/transfers/$id'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get spks: ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body);
    return json['data']['attributes']['data'].toString();
  }
}
