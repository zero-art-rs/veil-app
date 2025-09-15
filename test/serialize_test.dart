import 'package:super_editor_markdown/super_editor_markdown.dart';


main() {
  final markdown = """
  # HEADING

  - [ ] FEFMKERFMERKMF
  - [ ] FEFMKERFMERKMF
  - [ ] FEFMKERFMERKMF

  ferl;fle;rfl,erfl,erl,;
  """;
  final doc = deserializeMarkdownToDocument(markdown);
  print(serializeDocumentToMarkdown(doc));
}
