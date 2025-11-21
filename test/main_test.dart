import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:uuid/v4.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/src/rust/frb_generated.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/utils/group_context_factory.dart';

Future<Talker> _initEnv() async {
  final logger = Talker();
  final tempDir = getTemporaryDirectory();
  Hive.init(tempDir.toString());
  await RustLib.init();

  return logger;
}

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logger = Talker();
  Hive.init('/tmp/hive_test');
  await RustLib.init();

  test('test local init and then synchronize with network', () async {
    final id = UuidV4().generate();
    final (groupContext, frame) = await GroupContextFactory.createGroupContext(
      groupName: 'name',
      groupID: id,
      owner: Account.withName('name'),
    );

    final documentState = DocumentState(
      id: id,
      crdt: BAutoCommit(),
      createdAt: DateTime.now(),
      groupContextParts: GroupContextParts.empty(),
    );

    SyncModel syncModel = SyncModel(
      documentState: documentState,
      groupContext: groupContext,
      logger: logger,
    );

    syncModel.setup(allowFullDocument: true);
  });
}
