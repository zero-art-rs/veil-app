import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:veil/src/rust/api/group_context.dart' as bridge;
import 'package:veil/storage/models.dart';

class GroupContextFactory {
  /// Returns group context and frame
  static Future<(bridge.BGroupContext, Uint8List)> createGroupContext({
    required String groupName,
    required String groupID,
    required Account owner,
  }) async {
    final groupInfo = bridge.BGroupInfo(id: groupID, name: groupName);
    final user = bridge.BUser(
      name: owner.name,
      publicKey: owner.keypair.rawPublicKey,
    );

    return await bridge.createGroup(
      identitySecretKey: owner.keypair.rawPrivateKey,
      groupInfo: groupInfo,
      user: user,
    );
  }
}

class GroupContextParts {
  final Uint8List validator;
  final Uint8List groupInfo;
  final BigInt epoch;
  final BigInt nonce;

  GroupContextParts({
    required this.validator,
    required this.groupInfo,
    required this.epoch,
    required this.nonce,
  });

  factory GroupContextParts.empty() => GroupContextParts(
    validator: Uint8List(0),
    groupInfo: Uint8List(0),
    epoch: BigInt.zero,
    nonce: BigInt.zero,
  );

  String toJsonString() {
    final map = {
      'validator': validator,
      'group_info': groupInfo,
      'epoch': epoch.toInt(),
      'nonce': nonce.toInt(),
    };
    return jsonEncode(map);
  }

  factory GroupContextParts.fromJsonString(String blob) {
    final map = jsonDecode(blob) as Map<String, dynamic>;
    return GroupContextParts(
      validator: Uint8List.fromList(List<int>.from(map['validator'])),
      groupInfo: Uint8List.fromList(List<int>.from(map['group_info'])),
      nonce: BigInt.from(map['nonce'] as int),
      epoch: BigInt.from(map['epoch'] as int),
    );
  }

  bridge.BGroupContext toGroupContext({required Uint8List identitySecretKey}) {
    return bridge.BGroupContext.fromParts(
      validator: validator,
      groupInfo: groupInfo,
      epoch: epoch,
      nonce: nonce,
      identitySecretKey: identitySecretKey,
    );
  }
}

extension BGroupContextExt on bridge.BGroupContext {
  Future<GroupContextParts> asParts() async {
    final (validator, groupInfo, epoch, nonce) = await toParts();

    return GroupContextParts(
      validator: validator,
      groupInfo: groupInfo,
      epoch: epoch,
      nonce: nonce,
    );
  }
}
