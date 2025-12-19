import 'package:diffutil_dart/diffutil.dart';
import 'package:veil/main.dart';
import 'package:veil/src/rust/api/automerge.dart';

/// Keeps all logical connection between [Markdown] and [BAutoCommit]
class EditorAutomergeUtils {
  static EditorAutomergeUtils instance = EditorAutomergeUtils();

  String toText(BAutoCommit autocommit) {
    final blocks = autocommit.getBlocks();
    final md = blocks.join('\n');
    return md;
  }

  void toDoc(String md, BAutoCommit automerge) {
    final oldBlocks = automerge.getBlocks();
    final newBlocks = md.split('\n').toList();

    final List<DataDiffUpdate<String>> updates = calculateListDiff(
      oldBlocks,
      newBlocks,
      detectMoves: false,
    ).getUpdatesWithData().toList();

    for (final update in updates) {
      switch (update) {
        case DataInsert<String> dataInsert:
          automerge.insertBlock(
            index: dataInsert.position,
            text: dataInsert.data,
          );
        case DataRemove<String> dataRemove:
          automerge.deleteBlock(index: dataRemove.position);
        case DataChange<String> dataChange:
          automerge.updateBlock(
            index: dataChange.position,
            text: dataChange.newData,
          );
        default:
          logger.warning('Unknown update type: ${update.runtimeType}');
      }
    }
  }
}
