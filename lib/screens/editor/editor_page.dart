import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:popover/popover.dart';
import 'package:provider/provider.dart';
import 'package:zk_notion_app/managers/sync_provider.dart';
import 'package:zk_notion_app/screens/doc_members.dart';
import 'package:zk_notion_app/screens/history_page.dart';
import 'package:zk_notion_app/widgets/square_rounded_btn.dart';
import 'package:zk_notion_app/widgets/sync_widget.dart';
import 'editor_page_vm.dart';
import 'package:zk_notion_app/utils/platform.dart';

class EditorPage extends StatelessWidget {
  final SyncProviderModel syncModel;
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
      create: (_) => EditorPageVm(syncModel)..init(),
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
          child: Text(vm.syncModel.document.title),
        ),
        actions: isDesktop
            ? [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  margin: const EdgeInsets.all(8),
                  child: SegmentedButton<EditorModes>(
                    segments: const <ButtonSegment<EditorModes>>[
                      ButtonSegment<EditorModes>(
                        value: EditorModes.view,
                        label: Text("View mode"),
                      ),
                      ButtonSegment<EditorModes>(
                        value: EditorModes.edit,
                        label: Text("Edit mode"),
                      ),
                    ],
                    selected: <EditorModes>{vm.selectedMode},
                    onSelectionChanged: (newSelection) {
                      vm.selectMode(newSelection.first);
                    },
                  ),
                ),

                if (vm.isSinking) SyncCircleView(),
              ]
            : [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  margin: const EdgeInsets.all(8),
                  child: SegmentedButton<EditorModes>(
                    segments: const <ButtonSegment<EditorModes>>[
                      ButtonSegment<EditorModes>(
                        value: EditorModes.view,
                        label: Text("View mode"),
                      ),
                      ButtonSegment<EditorModes>(
                        value: EditorModes.edit,
                        label: Text("Edit mode"),
                      ),
                    ],
                    selected: <EditorModes>{vm.selectedMode},
                    onSelectionChanged: (newSelection) {
                      vm.selectMode(newSelection.first);
                    },
                  ),
                ),

                if (vm.isSinking) SyncCircleView(),
                if (isMemberListAccessible)
                  IconButton(
                    icon: const Icon(Icons.group),
                    onPressed: () async {
                      final members = await vm.prepareMembers();
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DocumentMemberListScreen(
                            members: members,
                            doc: vm.syncModel.document,
                            groupContext: vm.syncModel.groupContext,
                          ),
                        ),
                      );
                    },
                  ),
                if (isHistoryAccessible)
                  IconButton(
                    icon: const Icon(Icons.history),
                    onPressed: () {
                      // vm.commit();
                      final changes = vm.prepareChanges();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HistoryPage(
                            items: changes,
                            doc: vm.syncModel.document,
                          ),
                        ),
                      );
                    },
                  ),
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
                          onChanged: (_) => vm.editMD(),
                        ),
                      ),

                      Container(
                        alignment: Alignment.bottomRight,
                        padding: EdgeInsets.all(12),
                        child: FilledButton(
                          onPressed: () => {},
                          child: const Text("Commit"),
                        ),
                      ),
                    ],
                  ),
                ),

              if (vm.selectedMode == EditorModes.edit && isDesktop)
                Container(width: 1, height: double.infinity, color: cs.outline),

              if (isDesktop)
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

          if (isDesktop)
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ModalSquareRoundedButton(
                  iconData: Icons.group_outlined,
                  onPressed: (context) async {
                    final members = await vm.prepareMembers();
                    if (!context.mounted) return;
                    showPopover(
                      context: context,
                      width: 360,
                      height: 680,
                      bodyBuilder: (_) => Navigator(
                        onGenerateRoute: (_) => MaterialPageRoute(
                          builder: (_) => DocumentMemberListScreen(
                            members: members,
                            doc: vm.syncModel.document,
                            groupContext: vm.syncModel.groupContext,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                ModalSquareRoundedButton(
                  iconData: Icons.history_sharp,
                  onPressed: (context) {
                    final changes = vm.prepareChanges();
                    showPopover(
                      context: context,
                      width: 360,
                      height: 680,
                      bodyBuilder: (_) => Navigator(
                        onGenerateRoute: (_) => MaterialPageRoute(
                          builder: (_) => HistoryPage(
                            items: changes,
                            doc: vm.syncModel.document,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}
