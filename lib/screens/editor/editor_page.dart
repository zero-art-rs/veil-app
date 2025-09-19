import 'package:flutter/material.dart';
import 'package:popover/popover.dart';
import 'package:provider/provider.dart';
import 'package:zk_notion_app/screens/doc_members.dart';
import 'package:zk_notion_app/screens/history_page.dart';
import 'package:zk_notion_app/storage/models.dart' as models;
import 'package:zk_notion_app/widgets/square_rounded_btn.dart';
import 'editor_page_vm.dart';
import 'package:super_editor/super_editor.dart';
import 'package:zk_notion_app/utils/platform.dart';

class EditorPage extends StatelessWidget {
  final models.Document doc;
  final bool isMemberListAccessible;
  final bool isHistoryAccessible;
  final bool readOnly;

  const EditorPage({
    super.key,
    required this.doc,
    this.isMemberListAccessible = true,
    this.isHistoryAccessible = true,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditorPageVm(doc.id)..init(),
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
    final th = Theme.of(context).textTheme;
    final isDesktop = PlatformUtils.isDesktop;

    if (vm.groupContext == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: cs.onSurface,
      appBar: AppBar(
        title: Text(
          vm.doc!.title,
          style: th.titleLarge!.apply(color: cs.surface),
        ),
        backgroundColor: cs.onSurface,
        foregroundColor: Colors.black,
        actions: isDesktop
            ? [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: cs.tertiaryContainer,
                  ),
                  child: Text(
                    readOnly ? 'Read mode' : 'Editable mode',
                    style: th.bodyLarge,
                  ),
                ),
              ]
            : [
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
                            doc: vm.doc!,
                            groupContext: vm.groupContext!,
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
                          builder: (_) =>
                              HistoryPage(items: changes, doc: vm.doc!),
                        ),
                      );
                    },
                  ),
              ],
      ),
      body: Stack(
        children: [
          SuperEditor(editor: vm.editor, focusNode: FocusNode()),
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
                            doc: vm.doc!,
                            groupContext: vm.groupContext!,
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
                          builder: (_) =>
                              HistoryPage(items: changes, doc: vm.doc!),
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
