import 'dart:convert';

import 'package:uuid/v4.dart';
import 'package:veil/api/spk_client.dart';
import 'package:veil/managers/sharing/spk_provider.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/secret_factory.dart';

class OwnedSpk {}

class ContactSpk {}

class SpkShareData {
  final List<int> identityPublicKey;
  final List<SpkReceiveModel> spks;
  final ExternalAccount account;

  SpkShareData({
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

  factory SpkShareData.fromJson(Map<String, dynamic> json) {
    return SpkShareData(
      identityPublicKey: base64Decode(json['identity_public_key'].toString()),
      spks: (json['spks'] as List)
          .map((e) => SpkReceiveModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      account: ExternalAccount.fromJson(
        json['account'] as Map<String, dynamic>,
      ),
    );
  }
}

class SharedSpkRevealData {
  final String blobId;
  final List<int> encryptionKey;
  SharedSpkRevealData({required this.blobId, required this.encryptionKey});

  Map<String, dynamic> toJson() {
    return {'blob_id': blobId, 'encryption_key': base64Encode(encryptionKey)};
  }

  factory SharedSpkRevealData.fromJson(Map<String, dynamic> json) {
    return SharedSpkRevealData(
      blobId: json['blob_id'].toString(),
      encryptionKey: base64Decode(json['encryption_key'].toString()),
    );
  }
}

class SpkManager {
  static final instance = SpkManager();
  final _db = DB.instance;

  Future<SharedSpkRevealData> createAccountSpks(Account account) async {
    final spks = SpkProvider.instance.prepareSpkList(
      secretKey: account.keypair.rawPrivateKey,
    );

    final receiveSpks = spks.map((e) => e.downgrade()).toList();

    final shareData = SpkShareData(
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

    await _db.insertOwnedSpks(spks);
    return SharedSpkRevealData(blobId: blobId, encryptionKey: encryptionKey);
  }

  Future<SpkShareData> getSpk(SharedSpkRevealData payload) async {
    final cipher = await SpkClient.instance.getSpk(payload.blobId);

    final spkBytes = SecretManager.intance.decrypt(
      base64Decode(cipher),
      payload.encryptionKey,
    );

    final spk = SpkShareData.fromJson(jsonDecode(utf8.decode(spkBytes)));

    for (var sp in spk.spks) {
      final verified = schnorrVerify(
        pk: spk.identityPublicKey,
        message: sp.publicKey,
        signature: sp.signature,
      );

      if (!verified) {
        throw Exception('Failed to verify spks');
      }
    }

    return spk;
  }
}
