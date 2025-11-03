import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:provider/provider.dart';

import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/widgets/sync_widget.dart';
import 'editor_page_vm.dart';
import 'package:veil/utils/platform.dart';

class EditorPage extends StatelessWidget {
  final SyncModel syncModel;
  final bool isMemberListAccessible;
  final bool isHistoryAccessible;
  final bool readOnly;

  const EditorPage({
    super.key,
    required this.syncModel,
    this.isMemberListAccessible = true,
    this.isHistoryAccessible = true,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EditorPageVm>(
      create: (_) => EditorPageVm(syncModel)..init(context),
      child: _EditorPageView(
        isMemberListAccessible: isMemberListAccessible,
        isHistoryAccessible: isHistoryAccessible,
        readOnly: readOnly,
      ),
    );
  }
}

class _EditorPageView extends StatelessWidget {
  final bool isMemberListAccessible;
  final bool isHistoryAccessible;
  final bool readOnly;

  const _EditorPageView({
    required this.isMemberListAccessible,
    required this.isHistoryAccessible,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorPageVm>();
    final cs = Theme.of(context).colorScheme;
    final isDesktop = PlatformUtils.isDesktop;

    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: TextField(
            decoration: const InputDecoration.collapsed(hintText: null),
            controller: vm.groupNameController,
            enabled: vm.syncModel.isChangingGroupMetaAllowed(),
            onSubmitted: (name) async =>
                await vm.updateGroupName(context, name),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await vm.previewPdf(context);
            },
            icon: Icon(Icons.picture_as_pdf),
            tooltip: 'Preview pdf',
          ),

          IconButton(
            tooltip: 'Copy md text',
            onPressed: () {
              vm.copyMd(context);
            },
            icon: Icon(Icons.copy),
          ),

          if (vm.allowWriteEvents)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: SegmentedButton<EditorModes>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<EditorModes>>[
                  ButtonSegment<EditorModes>(
                    value: EditorModes.view,
                    label: Icon(Icons.menu_book),
                  ),
                  ButtonSegment<EditorModes>(
                    value: EditorModes.edit,
                    label: Icon(Icons.edit),
                  ),
                ],
                selected: <EditorModes>{vm.selectedMode},
                onSelectionChanged: (newSelection) async {
                  await vm.selectMode(newSelection.first);
                },
              ),
            ),

          if (vm.documentStatus == EditorDocumentStatus.local)
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Read-only mode"),
                    content: const Text(
                      "The owner of this document removed you from the group, you are now in read-only mode.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (vm.documentStatus == EditorDocumentStatus.corrupted)
            IconButton(
              icon: const Icon(Icons.warning_amber),
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(cs.error),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Document corrupted"),
                    content: const Text(
                      "Something wrong happened with this document, it is corrupted. Please contact the developers.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (vm.isSinking) SyncCircleView(),
        ],
      ),
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (vm.selectedMode == EditorModes.edit)
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: vm.mdEditor,
                          decoration: const InputDecoration(
                            hintText: "Start writing...",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          onChanged: (_) => vm.notify(),
                        ),
                      ),
                    ],
                  ),
                ),

              if (vm.selectedMode == EditorModes.edit && isDesktop)
                Container(width: 1, height: double.infinity, color: cs.outline),

              if (!(!isDesktop && vm.selectedMode == EditorModes.edit))
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: GptMarkdown(
                        vm.mdEditor.text,
                        useDollarSignsForLatex: true,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
