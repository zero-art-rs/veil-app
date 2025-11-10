import 'dart:convert';

import 'package:veil/api/group_api_client.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/group_context_factory.dart';

class InviteManager {
  final accountStorage = AccountSecureStorage.instance;
  static final InviteManager instance = InviteManager._();
  InviteManager._();

  Future<(BGroupContext, DocumentState)> join(String base64Invite) async {
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
      identitySecretKey:
          AccountSecureStorage.instance.account.keypair.rawPrivateKey,
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

    return (groupContext, document);
  }
}
