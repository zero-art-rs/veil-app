import 'dart:convert';

import 'package:talker_flutter/talker_flutter.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/managers/sync_provider/local_crdt_storage.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/storage/models/document_state.dart';
import 'package:veil/storage/models/keypair.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/group_context_factory.dart';

class Account {
  String name;
  final String actorId;
  final Keypair keypair;

  Account({required this.name, required this.actorId, required this.keypair});

  factory Account.withName(String name) {
    final keypair = Keypair.generate();

    return Account(
      name: name,
      actorId: hashPublicKey(pk: keypair.rawPublicKey),
      keypair: keypair,
    );
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      name: json['name'],
      actorId: json['actorId'],
      keypair: Keypair.fromJson(json['keypair']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'actorId': actorId, 'keypair': keypair.toJson()};
  }

  Future<SyncModel> acceptInvite(
    String base64Invite, {
    LocalCrdtStorage? localCrdtStorage,
    Talker? logger,
    bool saveToDb = true,
  }) async {
    final inviteBytes = base64Decode(base64Invite);
    final invite = Invite.fromBuffer(inviteBytes);

    final spkPublicKey = switch (invite.invite.whichInvite()) {
      InviteTbs_Invite.identifiedInvite =>
        invite.invite.identifiedInvite.spkPublicKey,
      InviteTbs_Invite.unidentifiedInvite => null,
      InviteTbs_Invite.notSet => null,
    };

    List<int> spkSecretKey = [];
    if (spkPublicKey != null) {
      spkSecretKey = await DB.instance.getOwnSpkSecret(spkPublicKey) ?? [];
    }

    final inviteContext = BInviteContext(
      identitySecretKey: keypair.rawPrivateKey,
      spkSecretKey: spkSecretKey,
      invite: inviteBytes,
    );

    final groupId = inviteContext.groupId();
    final challenge = await GroupApiClient.instance.getChallenge(groupId);

    final challengeBytes = base64Decode(challenge);
    final signature = inviteContext.signChallenge(
      nonce: [0],
      challenge: challengeBytes,
    );

    final artBase64 = await GroupApiClient.instance.fetchArtStructure(
      groupId: groupId,
      epoch: inviteContext.epoch().toInt(),
      signature: base64UrlEncode(signature),
      nonce: base64UrlEncode([0]),
      challenge: base64UrlEncode(challengeBytes),
      proofMode: ProofMode.useLeafKey,
      publicKey: base64UrlEncode(inviteContext.leafPublicKey()),
    );

    final groupContext = inviteContext.upgrade(
      publicArt: base64Decode(artBase64),
    );

    final document = DocumentState(
      id: groupId,
      crdt: BAutoCommit(),
      groupContextParts: await groupContext.asParts(),
      createdAt: DateTime.now(),
    );

    if (spkPublicKey != null) {
      await DB.instance.removeSpk(spkPublicKey);
    }

    final logger_ =
        logger ??
        Talker(
          logger: TalkerLogger(
            formatter: ColoredLoggerFormatter(),
            settings: TalkerLoggerSettings(defaultTitle: 'Sync model $groupId'),
          ),
        );

    return SyncModel(
      account: this,
      documentState: document,
      groupContext: groupContext,
      saveToDb: saveToDb,
      logger: logger_,
      localCrdtStorage: localCrdtStorage ?? DB.instance,
    );
  }
}
