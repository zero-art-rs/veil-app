import 'package:flutter/material.dart';

class CircularLoader extends StatelessWidget {
  const CircularLoader({
    super.key,
    this.size = 12,
    this.strokeWidth = 2,
    this.padding = const EdgeInsets.all(8),
    this.color,
  });

  final double size;
  final double strokeWidth;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          color: color ?? cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
