import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/src/rust/api/group_context.dart' as bridge;
import 'package:veil/storage/sqlite/consts.dart';
import 'package:veil/utils/group_context_factory.dart';

extension GroupContextExt on BGroupContext {
  GroupInfo retrieveGroupInfo() {
    return GroupInfo.fromBuffer(getGroupInfo());
  }

  User getOwner() {
    final groupInfo = retrieveGroupInfo();
    return groupInfo.members.firstWhere((e) => e.role.value == ownerRole);
  }
}

extension BPendingGroupContextExt on bridge.BPendingGroupContext {
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
