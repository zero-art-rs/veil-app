import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';

class CentrifugeProvider {
  final _url = 'https://sse-veil.distributedlab.com';

  static final instance = CentrifugeProvider();

  Future<Stream<SSEModel>> connect(String jwtToken) async {
    return SSEClient.subscribeToSSE(
      method: SSERequestType.GET,
      url: '$_url/connection/uni_sse?cf_connect={"token": "$jwtToken"}',
      header: <String, String>{},
    );
  }
  
}
