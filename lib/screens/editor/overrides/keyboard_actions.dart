import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

final actions = [
  toggleInteractionModeWhenCmdOrCtrlPressed,
  doNothingWhenThereIsNoSelection,
  scrollOnPageUpKeyPress,
  scrollOnPageDownKeyPress,
  scrollOnCtrlOrCmdAndHomeKeyPress,
  scrollOnCtrlOrCmdAndEndKeyPress,
  pasteWhenCmdVIsPressed,
  copyWhenCmdCIsPressed,
  cutWhenCmdXIsPressed,
  // undoWhenCmdZOrCtrlZIsPressed,
  // redoWhenCmdShiftZOrCtrlShiftZIsPressed,
  collapseSelectionWhenEscIsPressed,
  selectAllWhenCmdAIsPressed,
  moveLeftAndRightWithArrowKeys,
  moveUpAndDownWithArrowKeys,
  moveToLineStartWithHome,
  moveToLineEndWithEnd,
  tabToIndentListItem,
  shiftTabToUnIndentListItem,
  backspaceToUnIndentListItem,
  tabToIndentTask,
  shiftTabToUnIndentTask,
  backspaceToUnIndentTask,
  tabToIndentParagraph,
  shiftTabToUnIndentParagraph,
  backspaceToUnIndentParagraph,
  backspaceToConvertTaskToParagraph,
  backspaceToClearParagraphBlockType,
  cmdBToToggleBold,
  cmdIToToggleItalics,
  shiftEnterToInsertNewlineInBlock,
  enterToInsertNewTask,
  enterToUnIndentParagraph,
  enterToInsertBlockNewline,
  moveToLineStartOrEndWithCtrlAOrE,
  deleteToStartOfLineWithCmdBackspaceOnMac,
  deleteWordUpstreamWithAltBackspaceOnMac,
  deleteWordUpstreamWithControlBackspaceOnWindowsAndLinux,
  deleteUpstreamContentWithBackspace,
  deleteToEndOfLineWithCmdDeleteOnMac,
  deleteWordDownstreamWithAltDeleteOnMac,
  deleteWordDownstreamWithControlDeleteOnWindowsAndLinux,
  deleteDownstreamContentWithDelete,
  blockControlKeys,
  anyCharacterOrDestructiveKeyToDeleteSelection,
  anyCharacterToInsertInParagraph,
  anyCharacterToInsertInTextContent,
];

ExecutionInstruction enterToInsertNewTask({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.enter &&
      keyEvent.logicalKey != LogicalKeyboardKey.numpadEnter) {
    return ExecutionInstruction.continueExecution;
  }

  final selection = editContext.composer.selection;
  if (selection == null || !selection.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.document.getNodeById(selection.extent.nodeId);
  if (node is! TaskNode) {
    return ExecutionInstruction.continueExecution;
  }

  final newTaskId = Editor.createNodeId();

  editContext.editor.execute([
    InsertNodeAfterNodeRequest(
      existingNodeId: node.id,
      newNode: ParagraphNode(id: newTaskId, text: AttributedText('\n')),
    ),
    ChangeSelectionRequest(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: newTaskId,
          nodePosition: const TextNodePosition(offset: 0),
        ),
      ),
      SelectionChangeType.placeCaret,
      SelectionReason.userInteraction,
    ),
  ]);

  return ExecutionInstruction.haltExecution;
}
