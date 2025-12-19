import 'package:hex/hex.dart';
import 'package:veil/storage/models/account.dart';

class ExternalAccount {
  final String actorId;
  final String name;
  final List<int> rawPublicKey;

  String get publicKey => HEX.encode(rawPublicKey);

  ExternalAccount({
    required this.actorId,
    required this.name,
    required this.rawPublicKey,
  });

  Map<String, dynamic> toJson() => {
    'actorId': actorId,
    'name': name,
    'publicKey': rawPublicKey,
  };

  factory ExternalAccount.fromAccount(Account account) => ExternalAccount(
    actorId: account.actorId,
    name: account.name,
    rawPublicKey: account.keypair.rawPublicKey,
  );

  factory ExternalAccount.fromJson(Map<String, dynamic> json) {
    return ExternalAccount(
      actorId: json['actorId'],
      name: json['name'],
      rawPublicKey: List<int>.from(json['publicKey']),
    );
  }
}
