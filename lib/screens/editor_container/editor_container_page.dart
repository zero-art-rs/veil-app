import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/screens/editor/editor_page.dart';
import 'package:veil/screens/editor_container/editor_container_vm.dart';
import 'package:veil/utils/platform.dart';
import 'package:veil/widgets/square_rounded_btn.dart';

class EditorContainerPage extends StatelessWidget {
  final SyncModel syncModel;
  const EditorContainerPage({super.key, required this.syncModel});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EditorContainerViewModel>(
      create: (_) => EditorContainerViewModel(syncModel: syncModel),
      child: PlatformUtils.isDesktop
          ? _EditorContainerDesktopView()
          : _EditorContainerMobileView(),
    );
  }
}

class _EditorContainerDesktopView extends StatelessWidget {
  const _EditorContainerDesktopView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorContainerViewModel>();

    return Scaffold(
      body: Row(
        children: [
          Expanded(child: EditorPage(syncModel: vm.syncModel)),

          if (vm.isDesktop)
            MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) {
                  vm.setIsDragging(true);
                },
                onHorizontalDragUpdate: (details) {
                  vm.setSidebarWidth(details);
                },
                onHorizontalDragEnd: (_) {
                  vm.setIsDragging(false);
                },
                child: Container(
                  width: 3,
                  height: double.infinity,
                  color: Theme.of(context).colorScheme.primary.withAlpha(60),
                ),
              ),
            ),

          if (vm.currentPage != null)
            SizedBox(width: vm.sidebarWidth, child: vm.currentPage!),

          if (vm.currentPage != null)
            Container(
              width: 3,
              height: double.infinity,
              color: Theme.of(context).colorScheme.primary.withAlpha(60),
            ),

          SizedBox(
            child: Column(
              children: [
                ModalSquareRoundedButton(
                  iconData: Icons.group_outlined,
                  onPressed: (ctx) async {
                    vm.changeIndexPage(0);
                  },
                ),
                ModalSquareRoundedButton(
                  iconData: Icons.history_sharp,
                  onPressed: (ctx) {
                    vm.changeIndexPage(1);
                  },
                ),

                ModalSquareRoundedButton(
                  iconData: Icons.chat,
                  onPressed: (ctx) {
                    vm.changeIndexPage(2);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorContainerMobileView extends StatelessWidget {
  const _EditorContainerMobileView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorContainerViewModel>();

    return Scaffold(
      body: Stack(
        children: [
          EditorPage(syncModel: vm.syncModel),

          Container(
            margin: const EdgeInsets.only(right: 4, bottom: 32),
            alignment: Alignment.bottomRight,
            child: Column(
              children: [
                Spacer(),

                ModalSquareRoundedButton(
                  iconData: Icons.group_outlined,
                  onPressed: (ctx) async {
                    vm.openModal(context, EditorContainerPages.members);
                  },
                ),
                ModalSquareRoundedButton(
                  iconData: Icons.history_sharp,
                  onPressed: (ctx) {
                    vm.openModal(context, EditorContainerPages.history);
                  },
                ),

                ModalSquareRoundedButton(
                  iconData: Icons.chat,
                  onPressed: (ctx) {
                    vm.openModal(context, EditorContainerPages.chat);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
