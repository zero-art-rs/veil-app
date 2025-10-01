import 'dart:convert';
import 'package:dio/dio.dart';

class SpkClient {
  static final instance = SpkClient();
  final Dio _dio = Dio();

  final String baseUrl = 'https://veil.distributedlab.com';

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

    final response = await _dio.post(
      '$baseUrl/transistor/v1/public/transfers',
      data: jsonEncode(body),
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (response.statusCode! < 200 || response.statusCode! >= 300) {
      throw DioException.badResponse(
        statusCode: response.statusCode!,
        requestOptions: RequestOptions(path: response.requestOptions.path),
        response: response,
      );
    }
  }

  Future<String> getSpk(String id) async {
    final response = await _dio.get(
      '$baseUrl/transistor/v1/public/transfers/$id',
    );

    if (response.statusCode != 200) {
      throw DioException.badResponse(
        statusCode: response.statusCode!,
        requestOptions: RequestOptions(path: response.requestOptions.path),
        response: response,
      );
    }

    final json = response.data is String
        ? jsonDecode(response.data)
        : response.data;

    return json['data']['attributes']['data'].toString();
  }
}
