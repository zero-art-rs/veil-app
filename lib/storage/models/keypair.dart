import 'package:hex/hex.dart';
import 'package:veil/utils/secret_factory.dart';

class Keypair {
  final List<int> rawPublicKey;
  final List<int> rawPrivateKey;

  String get publicKeyHex => HEX.encode(rawPublicKey);
  String get privateKeyHex => HEX.encode(rawPrivateKey);

  Keypair({required this.rawPublicKey, required this.rawPrivateKey});

  factory Keypair.fromJson(Map<String, dynamic> json) {
    return Keypair(
      rawPublicKey: List<int>.from(json['rawPublicKey']),
      rawPrivateKey: List<int>.from(json['rawPrivateKey']),
    );
  }

  Map<String, dynamic> toJson() => {
    'rawPublicKey': rawPublicKey,
    'rawPrivateKey': rawPrivateKey,
  };

  static Keypair generate() {
    final (publicKey, secretKey) = SecretManager.intance.generateKeypair();
    return Keypair(rawPublicKey: publicKey, rawPrivateKey: secretKey);
  }
}
