import 'package:zk_notion_app/protos/zero_art.pb.dart';
import 'package:zk_notion_app/src/rust/api/group_context.dart';
import 'package:zk_notion_app/src/rust/api/group_context.dart' as bridge;
import 'package:zk_notion_app/storage/sqlite/consts.dart';
import 'package:zk_notion_app/utils/group_context_factory.dart';

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
