import 'dart:convert';
import 'dart:typed_data';

import 'package:zk_notion_app/api/client.dart';
import 'package:zk_notion_app/protos/zero_art.pb.dart';
import 'package:zk_notion_app/src/rust/api/group_context.dart';
import 'package:zk_notion_app/storage/account_storage.dart';

class InviteManager {
  final accountStorage = AccountStorage.instance;

  static final InviteManager instance = InviteManager();

  Future<BGroupContext> processJoin(String base64Invite) async {
    final account = await accountStorage.getAccount();

    if (account == null) {
      throw Exception('No account, unreachable flow');
    }

    final inviteBytes = base64Decode(base64Invite);
    final invite = Invite.fromBuffer(inviteBytes);

    final user = BUser(id: account.actorId, name: account.name);

    switch (invite.invite.whichInvite()) {
      case InviteTbs_Invite.identifiedInvite:
        destructIdentifiedInvite(
          invite: inviteBytes,
          identitySecretKey: [],
          spkSecretKey: [],
        );

        throw Exception('Unimplemented flow');
      case InviteTbs_Invite.unidentifiedInvite:
        return await _processUnidentifiedInvite(
          inviteBytes,
          Uint8List.fromList(account.keypair.rawPrivateKey),
          user,
        );
      case InviteTbs_Invite.notSet:
        throw Exception('Invalid invite type');
    }
  }

  Future<BGroupContext> _processUnidentifiedInvite(
    Uint8List inviteBytes,
    Uint8List secretKey,
    BUser user,
  ) async {
    final (leafSecret, stageKey, epoch, groupInfoBytes) =
        destructUnidentifiedInvite(invite: inviteBytes);

    final groupInfo = GroupInfo.fromBuffer(groupInfoBytes);
    final challenge = await GroupApiClient.instance.getChallenge(groupInfo.id);

    final challengeBytes = base64Decode(challenge);

    final signature = signChallenge(
      leafSecret: leafSecret,
      chatId: groupInfo.id,
      nonce: [0],
      challenge: challengeBytes,
      epoch: epoch,
    );

    final artBase64 = await GroupApiClient.instance.fetchArtStructure(
      groupId: groupInfo.id,
      epoch: epoch.toInt(),
      signature: base64UrlEncode(signature),
      nonce: base64UrlEncode([0]),
      challenge: base64UrlEncode(challengeBytes),
      proofMode: ProofMode.useLeafKey,
      publicKey: base64UrlEncode(publicKeyFromSecretKey(secretKey: leafSecret)),
    );

    final art = base64Decode(artBase64);

    final (groupContext, frame) = createGroupFromUnidentifiedInvite(
      identitySecretKey: secretKey,
      art: art,
      invite: inviteBytes,
      user: user,
    );

    await GroupApiClient.instance.sendFrame(
      groupId: groupInfo.id,
      frame: frame,
    );

    return groupContext;
  }
}
