import 'package:flutter/widgets.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/screens/chat/chat_page.dart';
import 'package:veil/screens/doc_members.dart';
import 'package:veil/screens/history_page.dart';

class EditorContainerViewModel extends ChangeNotifier {
  double sidebarWidth = 400;
  bool isDragging = false;
  final SyncModel syncModel;
  List<Widget> pages = [];
  Widget? currentPage;

  void changeIndexPage(int index) {
    currentPage = pages[index];
    notifyListeners();
  }

  void changeWidgetPage(Widget page) {
    currentPage = page;
    notifyListeners();
  }

  EditorContainerViewModel({required this.syncModel}) {
    pages = [
      HistoryPage(
        syncModel: syncModel,
        onBackPressed: closeSideBar,
        onChangeTap: (context, event) {
          
        },
      ),
      DocumentMemberListScreen(
        syncModel: syncModel,
        onBackPressed: closeSideBar,
      ),
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
    sidebarWidth = sidebarWidth.clamp(400, 1200);
    notifyListeners();
  }

  void setIsDragging(bool value) {
    isDragging = value;
    notifyListeners();
  }
}
