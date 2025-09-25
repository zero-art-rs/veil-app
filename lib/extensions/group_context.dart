import 'package:zk_notion_app/protos/zero_art.pb.dart';
import 'package:zk_notion_app/src/rust/api/group_context.dart';
import 'package:zk_notion_app/storage/sqlite/consts.dart';

extension GroupContextExt on BGroupContext {
  GroupInfo getGroupInfo() {
    return GroupInfo.fromBuffer(getGroupInf());
  }

  User getOwner() {
    final groupInfo = getGroupInfo();
    return groupInfo.members.firstWhere((e) => e.role.value == ownerRole);
  }
}
