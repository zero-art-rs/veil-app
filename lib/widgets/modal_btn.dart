import 'package:flutter/material.dart';

class PopupExample extends StatefulWidget {
  const PopupExample({super.key});

  @override
  State<PopupExample> createState() => _PopupExampleState();
}

class _PopupExampleState extends State<PopupExample> {
  OverlayEntry? _overlayEntry;

  void _togglePopup(BuildContext context, GlobalKey key) {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      return;
    }

    // Получаем позицию кнопки
    final renderBox = key.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx + renderBox.size.width + 8, // справа от кнопки
        top: offset.dy,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 200,
            height: 150,
            color: Colors.white, // пустое окно
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final buttonKey = GlobalKey();

    return Scaffold(
      appBar: AppBar(title: const Text("Popup Example")),
      body: Center(
        child: ElevatedButton(
          key: buttonKey,
          onPressed: () => _togglePopup(context, buttonKey),
          child: const Text("Show Popup"),
        ),
      ),
    );
  }
}
