import 'dart:convert';

import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/utils/secret_factory.dart';

class SpkReceiveModel {
  final List<int> publicKey;
  final List<int> signature;

  SpkReceiveModel({required this.publicKey, required this.signature});

  Map<String, dynamic> toJson() {
    return {
      'public_key': base64Encode(publicKey),
      'signature': base64Encode(signature),
    };
  }

  factory SpkReceiveModel.fromJson(Map<String, dynamic> json) {
    return SpkReceiveModel(
      publicKey: base64Decode(json['public_key'].toString()),
      signature: base64Decode(json['signature'].toString()),
    );
  }
}

class SpkSendModel {
  final List<int> publicKey;
  final List<int> signature;
  final List<int> privateKey;

  SpkSendModel({
    required this.publicKey,
    required this.signature,
    required this.privateKey,
  });

  SpkReceiveModel downgrade() {
    return SpkReceiveModel(publicKey: publicKey, signature: signature);
  }
}

class SpkProvider {
  static final instance = SpkProvider();

  List<SpkSendModel> prepareSpkList({
    required List<int> secretKey,
    int spkCount = 3,
  }) {
    final List<SpkSendModel> spkList = [];

    for (int i = 0; i < spkCount; i++) {
      final keypair = SecretManager.intance.generateKeypair();

      final signature = schnorrSign(sk: secretKey, message: keypair.$1);

      spkList.add(
        SpkSendModel(
          publicKey: keypair.$1.toList(),
          signature: signature.toList(),
          privateKey: keypair.$2.toList(),
        ),
      );
    }

    return spkList;
  }
}
