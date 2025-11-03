import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:veil/protos/zero_art.pb.dart';

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

  Future<String> getCentrifugoJWT({
    required String groupId,
    required int epoch,
    required String proof,
    required String challenge,
  }) async {
    final body = {
      'challenge': challenge,
      'epochs': [epoch],
      'chat_ids': [groupId],
      'nonce': base64Encode([0]),
      'proof': proof,
    };

    final response = await _http.post(
      Uri.parse('$baseUrl/centrifugo/auth'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get jwt centrifugo: ${response.statusCode} ${response.body}',
      );
    }

    final responseJson = jsonDecode(response.body);
    return responseJson['token'].toString();
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

  Future<SPFrames> getFrames({
    required String groupId,
    required String signature,
    required String nonce,
    int? messageSequenceNumber,
    int limit = 10,
    int skip = 0,
    int epoch = 0,
  }) async {
    final query = {
      if (messageSequenceNumber != null)
        'messageSequenceNumber': messageSequenceNumber.toString(),
      'limit': limit.toString(),
      'skip': skip.toString(),
      'signature': signature,
      'nonce': nonce,
      'epoch': epoch.toString(),
    };

    final uri = Uri.https(
      'veil.distributedlab.com',
      '/v1/group/$groupId/frames',
      query,
    );

    final response = await _http.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to get frames: ${response.statusCode} ${response.body}',
      );
    }

    return SPFrames.fromBuffer(response.bodyBytes);
  }
}
