import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';

class EditorAutomergeUtils {
  static EditorAutomergeUtils instance = EditorAutomergeUtils();

  MutableDocument toDoc(BAutoCommit autocommit) {
    final blocks = autocommit.getBlocks();
    final md = blocks.join('\n');
    return deserializeMarkdownToDocument(md);
  }

  fromDoc(MutableDocument doc, BAutoCommit automerge) {
    final blocks = _parseDoc(doc);
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

  List<String> _parseDoc(MutableDocument doc) {
    final md = serializeDocumentToMarkdown(doc);
    return md.split('\n').toList();
  }

  void updateMutableDocumentFromAutomerge(
    Editor editor,
    BAutoCommit automerge,
  ) {
    final doc = editor.document;
    final length = automerge.blocksLength().toInt();

    final requests = List<EditRequest>.empty(growable: true);

    // 1. Update or insert nodes
    for (var i = 0; i < length; i++) {
      final text = automerge.getBlock(index: BigInt.from(i));

      if (i < doc.nodeCount) {
        final node = doc.getNodeAt(i);

        if (node is ParagraphNode) {
          if (node.text.toPlainText() != text) {
            requests.add(
              ReplaceNodeRequest(
                existingNodeId: node.id,
                newNode: ParagraphNode(id: node.id, text: AttributedText(text)),
              ),
            );
          }
        } else {
          // Insert new node at index
          requests.add(
            InsertNodeAtIndexRequest(
              nodeIndex: i,
              newNode: ParagraphNode(
                id: Editor.createNodeId(),
                text: AttributedText(text),
              ),
            ),
          );
        }
      }
    }

    // while (doc.nodeCount > length) {
    //   final lastNode = doc.getNodeAt(doc.nodeCount - 1)!;
    //   requests.add(DeleteNodeRequest(nodeId: lastNode.id));
    // }

    editor.execute(requests);
  }
}
