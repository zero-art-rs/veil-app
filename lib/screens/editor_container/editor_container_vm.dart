import 'package:flutter/material.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/screens/chat/chat_page.dart';
import 'package:veil/screens/doc_members.dart';
import 'package:veil/screens/history_page.dart';
import 'package:veil/utils/platform.dart';

enum EditorContainerPages { members, history, chat }

class EditorContainerViewModel extends ChangeNotifier {
  double sidebarWidth = 400;
  bool isDragging = false;
  final SyncModel syncModel;
  List<Widget> pages = [];
  Widget? currentPage;

  bool get isDesktop => PlatformUtils.isDesktop;

  void changePage(EditorContainerPages page) {
    currentPage = pages[page.index];
    notifyListeners();
  }

  void changeWidgetPage(Widget page) {
    currentPage = page;
    notifyListeners();
  }

  EditorContainerViewModel({required this.syncModel}) {
    pages = [
      DocumentMemberListScreen(
        syncModel: syncModel,
        onBackPressed: closeSideBar,
      ),
      HistoryPage(syncModel: syncModel, onBackPressed: closeSideBar),
      ChatPage(syncModel: syncModel, onBackPressed: closeSideBar),
    ];

    notifyListeners();
  }

  void closeSideBar() {
    currentPage = null;
    notifyListeners();
  }

  void setSidebarWidth(DragUpdateDetails details) {
    sidebarWidth -= details.delta.dx;
    sidebarWidth = sidebarWidth.clamp(360, 1200);
    notifyListeners();
  }

  void setIsDragging(bool value) {
    isDragging = value;
    notifyListeners();
  }

  void openModal(BuildContext context, EditorContainerPages page) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: pages[page.index],
        );
      },
    );
  }
}
