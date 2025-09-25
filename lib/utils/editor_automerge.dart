import 'package:zk_notion_app/src/rust/api/automerge.dart';

class EditorAutomergeUtils {
  static EditorAutomergeUtils instance = EditorAutomergeUtils();

  String toDoc(BAutoCommit autocommit) {
    final blocks = autocommit.getBlocks();
    final md = blocks.join('\n');
    return md;
  }

  void fromDoc(String md, BAutoCommit automerge) {
    final blocks = md.split('\n').toList();
    final length = automerge.blocksLength().toInt();

    for (final (index, block) in blocks.indexed) {
      if (index < length) {
        automerge.updateBlock(index: BigInt.from(index), text: block);
      } else {
        automerge.insertBlock(index: BigInt.from(index), text: block);
      }
    }

    final toDelete = length - blocks.length;

    if (toDelete > 0) {
      _removeLastN(automerge, toDelete, length);
    }
  }

  void _removeLastN(BAutoCommit automerge, int n, int length) {
    final start = length - n;
    for (int i = length - 1; i >= start; i--) {
      automerge.deleteBlock(index: BigInt.from(i));
    }
  }
}
