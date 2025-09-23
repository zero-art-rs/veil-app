import 'package:centrifuge/centrifuge.dart' as centrifuge;

class CentrifugeProvider {
  final _baseUrl = 'https://sse-veil.distributedlab.com';

  static final instance = CentrifugeProvider();

  Future<centrifuge.Client> connect(String jwtToken) async {
    final client = centrifuge.createClient(
      '$_baseUrl/connection/uni_sse',
      centrifuge.ClientConfig(token: jwtToken),
    );

    await client.connect();

    return client;
  }
}
