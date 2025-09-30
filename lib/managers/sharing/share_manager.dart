import 'dart:convert';

import 'package:uuid/v4.dart';
import 'package:veil/api/spk_client.dart';
import 'package:veil/managers/sharing/spk_provider.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/utils/secret_factory.dart';

class Spk {
  final List<int> identityPublicKey;
  final List<SpkReceiveModel> spks;
  final ExternalAccount account;

  Spk({
    required this.identityPublicKey,
    required this.spks,
    required this.account,
  });

  Map<String, dynamic> toJson() {
    return {
      'identity_public_key': base64Encode(identityPublicKey),
      'spks': spks.map((e) => e.toJson()).toList(),
      'account': account.toJson(),
    };
  }

  factory Spk.fromJson(Map<String, dynamic> json) {
    return Spk(
      identityPublicKey: base64Decode(json['identity_public_key'].toString()),
      spks: json['spks'].map((e) => SpkReceiveModel.fromJson(e)).toList(),
      account: ExternalAccount.fromJson(json['account']),
    );
  }
}

class SpkManager {
  final secureStorage = AppSecureStorage.instance;

  Future<void> shareContactWithQR() async {}

  Future<(String, List<int>)> createAccountSpks(Account account) async {
    final spks = SpkProvider.instance.prepareSpkList(
      secretKey: account.keypair.rawPrivateKey,
    );

    for (var spk in spks) {
      await secureStorage.setSpk(spk.publicKey, spk.privateKey);
    }

    final receiveSpks = spks.map((e) => e.downgrade()).toList();

    final shareData = Spk(
      identityPublicKey: account.keypair.rawPublicKey,
      spks: receiveSpks,
      account: ExternalAccount.fromAccount(account),
    );

    final (cipher, encryptionKey) = SecretManager.intance.encrypt(
      utf8.encode(jsonEncode(shareData.toJson())),
    );

    final blobId = UuidV4().generate();
    await SpkClient.instance.sendSPKs(
      id: blobId,
      encryptedBlob: base64Encode(cipher),
    );

    return (blobId, encryptionKey);
  }

  Future<Spk> getSpk(String blobId, List<int> encryptionKey) async {
    final cipher = await SpkClient.instance.getSpk(blobId);

    final spkBytes = SecretManager.intance.decrypt(
      base64Decode(cipher),
      encryptionKey,
    );

    final spk = Spk.fromJson(jsonDecode(utf8.decode(spkBytes)));

    for (var spk in spk.spks) {
      final verified = schnorrVerify(
        pk: spk.publicKey,
        message: spk.publicKey,
        signature: spk.signature,
      );

      if (!verified) {
        throw Exception('Invalid spk');
      }
    }

    return spk;
  }
}
