import 'package:flutter/material.dart';

class ModalSquareRoundedButton extends StatelessWidget {
  final Function(BuildContext context)? onPressed;
  final IconData iconData;

  const ModalSquareRoundedButton({
    super.key,
    required this.iconData,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      alignment: Alignment.bottomRight,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Builder(
          builder: (buttonCtx) => ElevatedButton(
            onPressed: () => onPressed?.call(buttonCtx),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Icon(iconData, size: 24),
          ),
        ),
      ),
    );
  }
}
