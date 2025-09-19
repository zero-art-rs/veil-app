import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

enum ProofMode { useRootKey, useLeafKey }

extension ProofModeX on ProofMode {
  String get value {
    switch (this) {
      case ProofMode.useRootKey:
        return "use_root_key";
      case ProofMode.useLeafKey:
        return "use_leaf_key";
    }
  }
}

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

  Future<String> getChallenge(String groupId) async {
    final url = Uri.parse('$baseUrl/v1/group/$groupId/challenge');

    final response = await _http.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get challenge: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    return data['challenge'] as String;
  }

  Future<String> fetchArtStructure({
    required String groupId,
    required int epoch,
    required String signature,
    required String nonce,
    required String challenge,
    required ProofMode proofMode,
    required String publicKey,
  }) async {
    final uri = Uri.parse("$baseUrl/v1/group/$groupId/$epoch").replace(
      queryParameters: {
        'signature': signature,
        'nonce': nonce,
        'challenge': challenge,
        'proofMode': proofMode.value,
        'publicKey': publicKey,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch art structure: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    return data['art'] as String;
  }
}
