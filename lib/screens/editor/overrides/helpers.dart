import 'package:super_editor/super_editor.dart';
import 'package:zk_notion_app/screens/editor/overrides/checkbox_reaction.dart';

Editor createDefaultDocumentEditorOverriden({
  required MutableDocument document,
  required MutableDocumentComposer composer,
  HistoryGroupingPolicy historyGroupingPolicy = defaultMergePolicy,
  bool isHistoryEnabled = false,
}) {
  final editor = Editor(
    editables: {Editor.documentKey: document, Editor.composerKey: composer},
    requestHandlers: List.from(defaultRequestHandlers),
    historyGroupingPolicy: historyGroupingPolicy,
    reactionPipeline: List.from([
      ...defaultEditorReactions,
      CheckboxConversionReaction(),
    ]),
    isHistoryEnabled: isHistoryEnabled,
  );

  return editor;
}

