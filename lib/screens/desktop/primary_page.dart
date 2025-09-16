import 'package:flutter/material.dart';
import 'package:popover/popover.dart';
import 'package:provider/provider.dart';
import 'package:zk_notion_app/screens/account_page.dart';
import 'package:zk_notion_app/screens/contacts_page.dart';
import 'package:zk_notion_app/screens/desktop/primary_page_vm.dart';
import 'package:zk_notion_app/screens/difference_page.dart';
import 'package:zk_notion_app/screens/doc_members.dart';
import 'package:zk_notion_app/screens/editor/editor_page.dart';
import 'package:zk_notion_app/screens/history_page.dart';
import 'package:zk_notion_app/storage/models.dart';
import 'package:zk_notion_app/utils/banner.dart';
import 'package:zk_notion_app/widgets/sidebar.dart';
import 'package:zk_notion_app/widgets/square_rounded_btn.dart';

import '../../main.dart';

class DesktopPrimaryPage extends StatefulWidget {
  const DesktopPrimaryPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return StateDesktopPrimaryPage();
  }
}

class StateDesktopPrimaryPage extends State<DesktopPrimaryPage> {
  late final PrimaryPageViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = context.read<PrimaryPageViewModel>();
    _vm.init();
  }

  void _updateDocumentModal(
    BuildContext context,
    PrimaryPageViewModel vm,
    Document doc,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Update ${doc.title}'),
          content: SizedBox(
            width: 320,
            child: TextField(
              controller: vm.textEditingController,
              decoration: InputDecoration(label: Text('Input document title')),
            ),
          ),
          actions: <Widget>[
            Row(
              spacing: 16,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Cancel'),
                  ),
                ),

                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await vm.updateDocumentName(
                        context,
                        Document(
                          id: doc.id,
                          title: vm.textEditingController.text,
                          automergeDoc: doc.automergeDoc,
                          members: doc.members,
                          createdAt: doc.createdAt,
                          updatedAt: doc.updatedAt,
                        ),
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: Text('Update'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _areYouSureToDeleteDocumentModal(
    BuildContext context,
    PrimaryPageViewModel vm,
    Document doc,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Remove alert',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Text(
            'Are you sure you want to delete ${doc.title}?',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: <Widget>[
            Row(
              spacing: 16,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('No'),
                  ),
                ),

                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await vm.removeDocument(context, doc.id);
                      } catch (err) {
                        logger.e('Failed to remove document: $err');

                        if (!context.mounted) return;
                        TopBanner.show(
                          context: context,
                          message: 'Failed to remove document',
                          kind: TopBannerCases.error,
                        );
                      }
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: Text('Yes'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showCreateDocumentModal(BuildContext context, PrimaryPageViewModel vm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create document'),
          content: SizedBox(
            width: 320,
            child: TextField(
              controller: _vm.textEditingController,
              decoration: InputDecoration(label: Text('Input document title')),
            ),
          ),
          actions: <Widget>[
            Row(
              spacing: 16,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Cancel'),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await vm.createDocument(context);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: Text('Create'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.watch<PrimaryPageViewModel>();

    return Scaffold(
      backgroundColor: cs.onSurface,
      body: Row(
        children: [
          SideNav(
            extended: true,
            entries: [
              SideNavItem(
                icon: Icons.account_box_rounded,
                label: 'Account',
                onTap: () => vm.setSelectedPage(AccountPage()),
              ),
              SideNavItem(
                icon: Icons.group,
                label: 'Contacts',
                onTap: () => vm.setSelectedPage(ContactsScreen()),
              ),
              SideNavSpace(24),
              SideNavHeader(
                label: 'Documents',
                trailingBuilder: () => IconButton(
                  icon: Icon(Icons.add, size: 16),
                  onPressed: () => _showCreateDocumentModal(context, vm),
                ),
              ),
              SideNavDivider(),
              ...vm.docs.indexed.map(
                (doc) => SideNavItem(
                  icon: Icons.description_outlined,
                  label: doc.$2.title,
                  onTap: () => vm.setSelectedPage(
                    EditorPage(key: doc.$2.key, doc: doc.$2),
                  ),
                  trailingBuilder: () => PopupMenuButton(
                    icon: Icon(Icons.more_vert_rounded),
                    itemBuilder: (context) {
                      return [
                        PopupMenuItem(
                          value: 0,
                          child: Row(
                            spacing: 16,
                            children: [Icon(Icons.edit), Text('Edit')],
                          ),
                          onTap: () =>
                              _updateDocumentModal(context, vm, doc.$2),
                        ),
                        PopupMenuItem(
                          value: 1,
                          child: Row(
                            spacing: 16,
                            children: [Icon(Icons.delete), Text('Delete')],
                          ),
                          onTap: () => _areYouSureToDeleteDocumentModal(
                            context,
                            vm,
                            doc.$2,
                          ),
                        ),
                      ];
                    },
                  ),
                ),
              ),
            ],
            selectedIndex: vm.selectedIndex,
            onSelected: (e) => vm.setSelectedIndex(e),
          ),
          Expanded(
            child: Stack(
              children: [
                vm.selectedPage,
                if (vm.selectedIndex > 4)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: 0,
                    children: [
                      ModalSquareRoundedButton(
                        iconData: Icons.group_outlined,
                        onPressed: (context) async {
                          final members = await vm.prepareMembers();

                          if (!context.mounted) return;
                          showPopover(
                            context: context,
                            direction: PopoverDirection.top,
                            transition: PopoverTransition.other,
                            width: 360,
                            height: 680,
                            arrowWidth: 0,
                            arrowDyOffset: 80,
                            backgroundColor: Colors.white,
                            barrierColor: Colors.black26,
                            bodyBuilder: (ctx) => Navigator(
                              onGenerateRoute: (settings) {
                                return MaterialPageRoute(
                                  builder: (_) => DocumentMemberListScreen(
                                    members: members,
                                    doc:
                                        vm.docs[vm.selectedIndex -
                                            PrimaryPageViewModel.constantTabs],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      ModalSquareRoundedButton(
                        iconData: Icons.history_sharp,
                        onPressed: (context) async {
                          if (!context.mounted) return;

                          final (changes, doc) = vm.prepareChanges();

                          showPopover(
                            context: context,
                            direction: PopoverDirection.top,
                            transition: PopoverTransition.other,
                            width: 360,
                            height: 680,
                            arrowWidth: 0,
                            arrowDyOffset: 80,
                            backgroundColor: Colors.white,
                            barrierColor: Colors.black26,
                            bodyBuilder: (ctx) => Navigator(
                              onGenerateRoute: (settings) {
                                return MaterialPageRoute(
                                  builder: (_) => HistoryPage(
                                    items: changes,
                                    doc:
                                        vm.docs[vm.selectedIndex -
                                            PrimaryPageViewModel.constantTabs],
                                    onChangeTap: (_, change) {
                                      var (before, after) = doc.automergeDoc
                                          .docsBeforeAfter(
                                            changeHash: change.changeHashHex,
                                          );
                                      vm.setSelectedPage(
                                        DifferencePage(
                                          onClose: () => vm.setSelectedPage(
                                            EditorPage(doc: doc),
                                          ),
                                          oldDoc: before.getBlocks(),
                                          newDoc: after.getBlocks(),
                                        ),
                                      );
                                      Navigator.pop(ctx);
                                    },
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
