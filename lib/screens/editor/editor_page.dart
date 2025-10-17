import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:popover/popover.dart';
import 'package:provider/provider.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/screens/doc_members.dart';
import 'package:veil/screens/history_page.dart';
import 'package:veil/widgets/square_rounded_btn.dart';
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
          if (vm.allowWriteEvents)
            SegmentedButton<EditorModes>(
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
          if (!vm.allowWriteEvents)
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
                      child: GptMarkdown(vm.mdEditor.text),
                    ),
                  ),
                ),
            ],
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ModalSquareRoundedButton(
                iconData: Icons.group_outlined,
                onPressed: (ctx) async {
                  if (isDesktop) {
                    showPopover(
                      context: ctx,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      constraints: BoxConstraints(
                        maxHeight: 640,
                        maxWidth: 360,
                        minHeight: 16,
                        minWidth: 9,
                      ),
                      bodyBuilder: (_) => Navigator(
                        onGenerateRoute: (_) => MaterialPageRoute(
                          builder: (_) =>
                              DocumentMemberListScreen(syncModel: vm.syncModel),
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DocumentMemberListScreen(syncModel: vm.syncModel),
                      ),
                    );
                  }
                },
              ),
              ModalSquareRoundedButton(
                iconData: Icons.history_sharp,
                onPressed: (ctx) {
                  if (isDesktop) {
                    showPopover(
                      context: ctx,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      constraints: BoxConstraints(
                        maxHeight: 640,
                        maxWidth: 360,
                        minHeight: 16,
                        minWidth: 9,
                      ),
                      bodyBuilder: (_) => Navigator(
                        onGenerateRoute: (_) => MaterialPageRoute(
                          builder: (_) => HistoryPage(syncModel: vm.syncModel),
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistoryPage(syncModel: vm.syncModel),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
