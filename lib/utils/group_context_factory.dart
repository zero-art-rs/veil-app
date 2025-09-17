import 'package:flutter/services.dart';
import 'package:zk_notion_app/protos/zero_art.pb.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:zk_notion_app/src/rust/api/group_context.dart' as bridge;
import 'package:zk_notion_app/storage/models.dart';

class GroupContextFactory {
  /// Returns group context and frame
  static (bridge.BGroupContext, Uint8List) createGroupContext({
    required String groupName,
    required String groupID,
    required Account owner,
    required BAutoCommit autoCommit,
  }) {
    final groupInfo = bridge.BGroupInfo(id: groupName, name: groupID);
    final user = bridge.BUser(name: owner.name, id: owner.actorId);

    final crdtPayload = CRDTPayload(
      incrementalChange: null,
      fullDocument: autoCommit.save(),
      mediaAttachment: null,
    ).writeToBuffer();

    final (groupContext, frame, _, _) = bridge.createGroup(
      identitySecretKey: owner.keypair.rawPrivateKey,
      user: user,
      groupInfo: groupInfo,
      // empty since we are not going to invite members in create group stage yet.
      identifiedMembersKeys: [],
      // empty since we are not going to invite members in create group stage yet.
      unidentifiedMembersCount: BigInt.from(0),
      payloads: [crdtPayload],
    );

    return (groupContext, frame);
  }
}

class GroupContextParts {
  final Uint8List leafSecret;
  final Uint8List art;
  final Uint8List stageKey;
  final BigInt epoch;
  final Uint8List groupInfoProto;

  GroupContextParts({
    required this.leafSecret,
    required this.art,
    required this.stageKey,
    required this.epoch,
    required this.groupInfoProto,
  });
}

class GroupContextManager {
  static final instance = GroupContextManager();

  /// Return leaf secret, art, stage_key, epoch, group_info protobuf
  GroupContextParts intoParts(bridge.BGroupContext context) {
    final (leafSecret, art, stageKey, epoch, groupInfo) = context.intoParts();

    return GroupContextParts(
      leafSecret: leafSecret,
      art: art,
      stageKey: stageKey,
      epoch: epoch,
      groupInfoProto: groupInfo,
    );
  }

  bridge.BGroupContext fromParts({
    required GroupContextParts parts,
    required Uint8List identitySecretKey,
  }) {
    return bridge.BGroupContext.fromParts(
      identitySecretKey: identitySecretKey,
      leafSecret: parts.leafSecret,
      art: parts.art,
      stk: parts.stageKey,
      epoch: parts.epoch,
      groupInfo: parts.groupInfoProto,
    );
  }
}
