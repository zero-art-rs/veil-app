import 'package:flutter/material.dart';
import 'package:popover/popover.dart';
import 'package:provider/provider.dart';
import 'package:zk_notion_app/screens/desktop/primary_page_vm.dart';
import 'package:zk_notion_app/screens/doc_members.dart';
import 'package:zk_notion_app/screens/history_page.dart';
import 'package:zk_notion_app/widgets/sidebar.dart';
import 'package:zk_notion_app/widgets/square_rounded_btn.dart';

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

  void _showCreateDocumentModal(BuildContext context, PrimaryPageViewModel vm) {
    showDialog(
      context: context,
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
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                vm.createDocument(context);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: Text('Create'),
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
              SideNavItem(icon: Icons.account_box_rounded, label: 'Account'),
              SideNavItem(icon: Icons.group, label: 'Contacts'),
              SideNavSpace(24),
              SideNavHeader(
                label: 'Documents',
                trailingBuilder: () => InkWell(
                  child: Icon(Icons.add, size: 16),
                  onTap: () => {_showCreateDocumentModal(context, vm)},
                ),
              ),
              SideNavDivider(),
              ...vm.docs.map(
                (doc) => SideNavItem(
                  icon: Icons.description_outlined,
                  label: doc.title,
                  trailingBuilder: () => IconButton(
                    onPressed: () async =>
                        await vm.removeDocument(context, doc.id),
                    icon: Icon(Icons.remove, size: 14),
                  ),
                ),
              ),
            ],
            onSelected: (value) => {vm.setSelectedIndex(value)},
            selectedIndex: vm.selectedIndex,
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
