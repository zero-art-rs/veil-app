import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';
import 'package:html/parser.dart' as html;


class FlowyUtils {
  static documentFromHtmlAutomerge(BAutoCommit doc) {
    final blocks = doc.getBlocks();
    final html =
        """<html>
<body>
${blocks.join('\n')}

</body>
</html>""";

    print(html);

    return htmlToDocument(html);
  }

  static htmlDoc2Automerge(String html, BAutoCommit automerge) {
    final blocks = parseHtml(html);
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
      removeLastN(automerge, toDelete, length);
    }
  }

  static void removeLastN(BAutoCommit automerge, int n, int length) {
    if (n <= 0) return;

    final start = length - n;
    for (int i = length - 1; i >= start; i--) {
      automerge.deleteBlock(index: BigInt.from(i));
    }
  }

  static List<String> parseHtml(String htmlStr) {
    return html
        .parse(htmlStr)
        .querySelectorAll('body > *')
        .map((e) => e.outerHtml)
        .toList();
  }
}
