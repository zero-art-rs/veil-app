import 'dart:math';
import 'dart:typed_data';

import 'package:veil/src/rust/api/group_context.dart';

class SecretManager {
  static final SecretManager intance = SecretManager._();
  late BSecretsFactory secretFactory = _secretFactory();

  SecretManager._();

  BSecretsFactory _secretFactory() {
    final random = Random.secure();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );

    return BSecretsFactory(seed: U8Array32(seed));
  }

  Uint8List generateSecretKey() {
    return secretFactory.generateSecret();
  }

  (Uint8List, Uint8List) generateKeypair() {
    return secretFactory.generateSecretWithPublicKey();
  }

  (Uint8List, Uint8List) encrypt(List<int> plainText) {
    return secretFactory.encrypt(plaintext: plainText);
  }

  Uint8List decrypt(List<int> cipherText, List<int> ecnryptionKey) {
    return secretFactory.decrypt(ciphertext: cipherText, okm: ecnryptionKey);
  }
}
