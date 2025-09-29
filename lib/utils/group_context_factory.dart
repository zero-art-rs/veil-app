import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:zk_notion_app/src/rust/api/group_context.dart' as bridge;
import 'package:zk_notion_app/storage/models.dart';

class GroupContextFactory {
  /// Returns group context and frame
  static (bridge.BGroupContext, Uint8List) createGroupContext({
    required String groupName,
    required String groupID,
    required Account owner,
  }) {
    final groupInfo = bridge.BGroupInfo(id: groupID, name: groupName);
    final user = bridge.BUser(
      name: owner.name,
      publicKey: owner.keypair.rawPublicKey,
    );

    return bridge.createGroup(
      identitySecretKey: owner.keypair.rawPrivateKey,
      groupInfo: groupInfo,
      user: user,
    );
  }
}

class GroupContextParts {
  final Uint8List leafSecret;
  final Uint8List art;
  final Uint8List stageKey;
  final BigInt epoch;
  final Uint8List groupInfoProto;
  final bool isLastSender;

  GroupContextParts({
    required this.leafSecret,
    required this.art,
    required this.stageKey,
    required this.epoch,
    required this.groupInfoProto,
    required this.isLastSender,
  });

  String toJsonString() {
    final map = {
      'leafSecret': leafSecret,
      'art': art,
      'stageKey': stageKey,
      'epoch': epoch.toInt(),
      'groupInfoProto': groupInfoProto,
      'isLastSender': isLastSender,
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
      isLastSender: map['isLastSender'] as bool,
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
      isLastSender: isLastSender,
    );
  }
}

extension BGroupContextExt on bridge.BGroupContext {
  GroupContextParts asParts() {
    final (leafSecret, art, stageKey, epoch, groupInfo, isLastSender) =
        toParts();

    return GroupContextParts(
      leafSecret: leafSecret,
      art: art,
      stageKey: stageKey,
      epoch: epoch,
      groupInfoProto: groupInfo,
      isLastSender: isLastSender,
    );
  }
}
