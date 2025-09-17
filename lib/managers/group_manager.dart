import 'dart:math';

import 'package:flutter/services.dart';
import 'package:zk_notion_app/src/rust/api/group_context.dart' as bridge;
import 'package:zk_notion_app/storage/models.dart';

class GroupManager {
  static final instance = GroupManager();

  /// Returns group context, frame
  (bridge.BGroupContext, Uint8List) createGroup({
    required String groupName,
    required String groupID,
    required Account owner,
  }) {
    final groupInfo = bridge.BGroupInfo(id: groupName, name: groupID);
    final user = bridge.BUser(name: owner.name, id: owner.actorId);

    // protobuff
    final payload = [[]];

    final (groupContext, frame, _, _) = bridge.createGroup(
      identitySecretKey: [], // store private key
      user: user,
      groupInfo: groupInfo,
      // empty since we are not going to invite members in create group stage yet.
      identifiedMembersKeys: [],
      // empty since we are not going to invite members in create group stage yet.
      unidentifiedMembersCount: BigInt.from(0),
      payloads: [], // full document proto,
    );

    return (groupContext, frame);
  }

  // Uint8List createFrame(bridge.BGroupContext context) {
  //   context.createFrame(payloads: payloads)

  //   context.processFrame(spFrame: spFrame)
  //   context.addMember(identityPublicKey: identityPublicKey, payloads: payloads)
  //   context.removeMember(leafPublicKey: leafPublicKey, payload: payload)
  // }
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
