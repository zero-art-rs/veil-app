import 'package:super_editor/super_editor.dart';

/// Converts "- [ ] task" or "- [x] task" at the beginning of a paragraph
/// into a TaskNode (checkbox), and keeps the paragraph for the remaining text.
class CheckboxConversionReaction extends ParagraphPrefixConversionReaction {
  static final _checkboxPattern = RegExp(r'^\[(|x)\]\s');

  @override
  RegExp get pattern => _checkboxPattern;

  const CheckboxConversionReaction();

  @override
  void onPrefixMatched(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
    ParagraphNode paragraph,
    String match,
  ) {
    final text = paragraph.text.toPlainText();
    final matchResult = _checkboxPattern.firstMatch(text);
    if (matchResult == null) {
      return;
    }

    final isChecked = matchResult.group(1) == "x";

    requestDispatcher.execute([
      ReplaceNodeRequest(
        existingNodeId: paragraph.id,
        newNode: TaskNode(
          id: paragraph.id,
          isComplete: isChecked,
          text: AttributedText(),
        ),
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: paragraph.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.contentChange,
      ),
    ]);
  }
}
