import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/src/rust/api/group_context.dart';
import 'package:veil/storage/sqlite/consts.dart';

extension GroupContextExt on BGroupContext {
  GroupInfo retrieveGroupInfo() {
    return GroupInfo.fromBuffer(groupInfo());
  }

  User getOwner() {
    final groupInfo = retrieveGroupInfo();
    return groupInfo.members.firstWhere((e) => e.role.value == ownerRole);
  }
}
