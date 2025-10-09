import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/screens/account_page.dart';
import 'package:veil/screens/contacts_page.dart';
import 'package:veil/screens/desktop/primary_page_vm.dart';
import 'package:veil/screens/editor/editor_page.dart';
import 'package:veil/widgets/banner.dart';
import 'package:veil/widgets/loader_dialog.dart';
import 'package:veil/widgets/sidebar.dart';

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

  void _areYouSureToDeleteDocumentModal(
    BuildContext context,
    PrimaryPageViewModel vm,
    GroupInfo groupInfo,
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
            'Are you sure you want to delete ${groupInfo.name}?',
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
                        await vm.removeDocument(context, groupInfo.id);
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

  Future<void> _showCreateDocumentModal(
    BuildContext context,
    PrimaryPageViewModel vm,
  ) async {
    // final result = await showLoaderDialog<String>(
    //   context: context,
    //   initial: const Text("Create document"),
    //   work: () async {
    //     await Future.delayed(const Duration(seconds: 2));
    //     return "Done!";
    //   },
    // );

    final style = Theme.of(context).textTheme;

    await showLoaderDialog(
      context: context,
      initialBuilder: (context, start) => SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 24,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text('Create document', style: style.titleLarge),
            ),

            // Spacer(),
            TextField(
              controller: _vm.textEditingController,
              decoration: InputDecoration(label: Text('Input document title')),
            ),

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
                      start();
                    },
                    child: Text('Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      work: () async {
        await vm.createDocument(context);
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
                  onPressed: () async =>
                      await _showCreateDocumentModal(context, vm),
                ),
              ),
              SideNavDivider(),
              ...vm.syncModels.indexed.map(
                (doc) => SideNavItem(
                  icon: Icons.description_outlined,
                  label: doc.$2.groupContext.retrieveGroupInfo().name,
                  onTap: () => vm.setSelectedPage(
                    EditorPage(key: doc.$2.document.key, syncModel: doc.$2),
                  ),
                  trailingBuilder: () => PopupMenuButton(
                    icon: Icon(Icons.more_vert_rounded),
                    itemBuilder: (context) {
                      return [
                        PopupMenuItem(
                          enabled: false,
                          value: 0,
                          child: Row(
                            spacing: 16,
                            children: [Icon(Icons.edit), Text('Edit')],
                          ),
                          onTap: () => {},
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
                            doc.$2.groupContext.retrieveGroupInfo(),
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
          Expanded(child: vm.selectedPage),
        ],
      ),
    );
  }
}
