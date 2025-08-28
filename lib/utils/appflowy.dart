import 'package:zk_notion_app/src/rust/api/automerge.dart';

class FlowyUtils {
  static Map<String, dynamic> toFlowyDoc(List<String> blocks) {
    return {
      "document": {
        "type": "page",
        "children": [
          ...blocks.map((b) => convertToParagraph(b)),
        ],
      },
    };
  }

  static Map<String, dynamic> convertToParagraph(String block) {
    return {
      "type": "paragraph",
      "data": {
        "delta": [
          {"insert": block},
        ],
      },
    };
  }

  static Map<String, dynamic> automerge2Flowy(BAutoCommit doc) {
    final blocks = doc.getBlocks();
    return toFlowyDoc(blocks);
  }
}
