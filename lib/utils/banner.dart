import 'package:flutter/material.dart';

enum TopBannerCases { success, error, info }

class TopBanner {
  static Color _color(TopBannerCases c) {
    switch (c) {
      case TopBannerCases.success:
        return Colors.green;
      case TopBannerCases.error:
        return Colors.red;
      case TopBannerCases.info:
        return Colors.blue;
    }
  }

  static Icon _icon(TopBannerCases c) {
    switch (c) {
      case TopBannerCases.success:
        return const Icon(Icons.check);
      case TopBannerCases.error:
        return const Icon(Icons.error);
      case TopBannerCases.info:
        return const Icon(Icons.info);
    }
  }

  static void show({
    required BuildContext context,
    required String message,
    TopBannerCases kind = TopBannerCases.success,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    final controller = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 300),
    );

    final slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    final fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeIn));

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: fade,
            child: Material(
              color: _color(kind),
              child: InkWell(
                onTap: () async {
                  await controller.reverse();
                  entry.remove();
                  controller.dispose();
                },
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Spacer(),
                        Icon(_icon(kind).icon, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        // Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    controller.forward();

    Future.delayed(const Duration(seconds: 2), () async {
      if (controller.isDismissed) return;
      await controller.reverse();
      entry.remove();
      controller.dispose();
    });
  }
}
