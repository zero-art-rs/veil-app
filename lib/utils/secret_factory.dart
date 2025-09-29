import 'dart:math';
import 'dart:typed_data';

import 'package:veil/src/rust/api/group_context.dart';

class SecretManager {
  static final SecretManager intance = SecretManager();

  Uint8List generateSecretKey() {
    final random = Random.secure();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );

    final secretKey = BSecretsFactory(seed: U8Array32(seed)).generateSecret();

    return secretKey;
  }

  (Uint8List, Uint8List) generateKeypair() {
    final random = Random.secure();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );

    final (publicKey, secretKey) = BSecretsFactory(
      seed: U8Array32(seed),
    ).generateSecretWithPublicKey();

    return (publicKey, secretKey);
  }
}
