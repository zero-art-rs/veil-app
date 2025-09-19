import 'dart:convert';

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
    final groupInfo = bridge.BGroupInfo(id: groupID, name: groupName);
    final user = bridge.BUser(name: owner.name, id: owner.actorId);

    final crdt = CRDTPayload(
      incrementalChange: null,
      fullDocument: autoCommit.save(),
      mediaAttachment: null,
    );

    final payload = Payload(crdt: crdt).writeToBuffer();

    final (groupContext, frame, _, _) = bridge.createGroup(
      identitySecretKey: owner.keypair.rawPrivateKey,
      user: user,
      groupInfo: groupInfo,
      // empty since we are not going to invite members in create group stage yet.
      identifiedMembersKeys: [],
      // empty since we are not going to invite members in create group stage yet.
      unidentifiedMembersCount: BigInt.from(1),
      payloads: [payload],
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

  String toJsonString() {
    final map = {
      'leafSecret': leafSecret,
      'art': art,
      'stageKey': stageKey,
      'epoch': epoch.toInt(),
      'groupInfoProto': groupInfoProto,
    };
    return jsonEncode(map);
  }

  factory GroupContextParts.fromJsonString(String blob) {
    final map = jsonDecode(blob) as Map<String, dynamic>;
    return GroupContextParts(
      leafSecret: Uint8List.fromList(List<int>.from(map['leafSecret'])),
      art: Uint8List.fromList(List<int>.from(map['art'])),
      stageKey: Uint8List.fromList(List<int>.from(map['stageKey'])),
      epoch: BigInt.from(map['epoch'] as int),
      groupInfoProto: Uint8List.fromList(List<int>.from(map['groupInfoProto'])),
    );
  }

  bridge.BGroupContext toGroupContext({required Uint8List identitySecretKey}) {
    return bridge.BGroupContext.fromParts(
      identitySecretKey: identitySecretKey,
      leafSecret: leafSecret,
      art: art,
      stk: stageKey,
      epoch: epoch,
      groupInfo: groupInfoProto,
    );
  }
}

extension BGroupContextExt on bridge.BGroupContext {
  GroupContextParts toParts() {
    final (leafSecret, art, stageKey, epoch, groupInfo) = intoParts();

    return GroupContextParts(
      leafSecret: leafSecret,
      art: art,
      stageKey: stageKey,
      epoch: epoch,
      groupInfoProto: groupInfo,
    );
  }
}
