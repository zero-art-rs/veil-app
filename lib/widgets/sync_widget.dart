import 'package:flutter/material.dart';

class SyncCircleView extends StatefulWidget {
  const SyncCircleView({super.key});

  @override
  State<SyncCircleView> createState() => _SyncCircleViewState();
}

class _SyncCircleViewState extends State<SyncCircleView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(); // крутится бесконечно
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(Icons.sync, size: 32, color: Colors.blue),
    );
  }
}
