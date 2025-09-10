import 'package:flutter/material.dart';

class DesktopAccountPage extends StatefulWidget {
  const DesktopAccountPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _DesktopAccountPageState();
  }
}

class _DesktopAccountPageState extends State<DesktopAccountPage> {
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Spacer(),
          Container(
            padding: EdgeInsets.all(12),
            alignment: Alignment.center,
            child: Text('Welcome home!', style: th.displayMedium),
          ),
          Spacer(),
        ],
      ),
    );
  }
}
