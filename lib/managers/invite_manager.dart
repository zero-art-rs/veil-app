import 'dart:convert';
import 'dart:typed_data';

import 'package:veil/api/client.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models.dart';

class InviteManager {
  final accountStorage = AccountStorage.instance;

  static final InviteManager instance = InviteManager();

  Future<(BPendingGroupContext, Document)> join(String base64Invite) async {
    final account = await accountStorage.getAccount();

    if (account == null) {
      throw Exception('No account, unreachable flow');
    }

    final inviteBytes = base64Decode(base64Invite);
    final invite = Invite.fromBuffer(inviteBytes);

    switch (invite.invite.whichInvite()) {
      case InviteTbs_Invite.identifiedInvite:
        // destructIdentifiedInvite(
        //   invite: inviteBytes,
        //   identitySecretKey: [],
        //   spkSecretKey: [],
        // );

        throw Exception('Unimplemented flow');
      case InviteTbs_Invite.unidentifiedInvite:
        return await _processUnidentifiedInvite(
          inviteBytes,
          Uint8List.fromList(account.keypair.rawPrivateKey),
        );
      case InviteTbs_Invite.notSet:
        throw Exception('Invalid invite type');
    }
  }

  Future<(BPendingGroupContext, Document)> _processUnidentifiedInvite(
    Uint8List inviteBytes,
    Uint8List secretKey,
  ) async {
    final inviteContext = BInviteContext(
      identitySecretKey: secretKey,
      spkSecretKey: [],
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

    final pendingGroupContext = inviteContext.upgrade(
      publicArt: base64Decode(artBase64),
    );

    final document = Document(
      id: groupId,
      automergeDoc: BAutoCommit(),
      groupContextParts: pendingGroupContext.asParts(),
      createdAt: DateTime.now(),
    );

    return (pendingGroupContext, document);
  }
}
