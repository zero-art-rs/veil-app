import 'package:flutter/material.dart';
import 'package:veil/assets/theme.dart';

class AppStyles {
  static ButtonStyle lightErrorButtonStyle = ButtonStyle(
    foregroundColor: WidgetStateColor.fromMap(<WidgetStatesConstraint, Color>{
      WidgetState.any: Colors.white,
    }),
    padding: WidgetStateProperty.fromMap(<WidgetStatesConstraint, EdgeInsets>{
      WidgetState.any: EdgeInsets.zero,
    }),
    shape:
        WidgetStateProperty.fromMap(<WidgetStatesConstraint, OutlinedBorder?>{
          WidgetState.any: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        }),
    backgroundColor: WidgetStateColor.fromMap(<WidgetStatesConstraint, Color>{
      WidgetState.any: MaterialTheme.darkScheme().error,
    }),
  );
}
