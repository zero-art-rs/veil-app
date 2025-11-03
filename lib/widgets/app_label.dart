import 'package:flutter/material.dart';

class AppLabel extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final TextStyle? textStyle;

  const AppLabel({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    this.borderRadius = 6,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.primaryContainer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        text,
        style: (textStyle ?? Theme.of(context).textTheme.labelSmall)?.copyWith(
          color: textColor ?? cs.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
