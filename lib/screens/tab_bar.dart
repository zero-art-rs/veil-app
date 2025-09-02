import 'package:flutter/material.dart';
import 'package:zk_notion_app/screens/account_page.dart';
import 'package:zk_notion_app/screens/contacts_page.dart';
import 'package:zk_notion_app/screens/docs_page.dart';
import 'package:zk_notion_app/screens/qr_scanner_page.dart';

class AppBottomTabBar extends StatefulWidget {
  const AppBottomTabBar({super.key});

  @override
  State<AppBottomTabBar> createState() => _AppBottomTabBarState();
}

class _AppBottomTabBarState extends State<AppBottomTabBar> {
  int _selectedIndex = 0;
  static const List<Widget> _widgetOptions = <Widget>[
    DocsPage(),
    QRScannerPage(),
    AccountPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_document),
            label: 'Docs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
