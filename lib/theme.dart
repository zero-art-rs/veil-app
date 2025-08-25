import 'package:flutter/material.dart';

/// 1) Brand palette (tweak hexes to match your design precisely)
class AppPalette {
  // Main colors
  static const primaryBlue = Color(0xFF3B82F6);
  static const primaryGreen = Color(0xFF22C55E);
  static const tint100 = Color(0xFFEFF6FF); // very light blue
  static const tint200 = Color(0xFFC7D2FE); // lavender-ish
  static const tint300 = Color(0xFFA3A3B3); // gray-violet accent

  // Semantic
  static const danger = Color(0xFFEF4444);
  static const lightDanger = Color(0xFFFF8587);
  static const warning = Color(0xFFD97706);
  static const success = Color(0xFF22C55E);
  static const info = Color(0xFF0EA5E9);

  // Gray set (light → dark)
  static const gray50 = Color(0xFFF3F4F6);
  static const gray100 = Color(0xFFE5E7EB);
  static const gray200 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray700 = Color(0xFF374151);
  static const gray900 = Color(0xFF111827);

  /// Optional Material swatch for primary
  static const MaterialColor primarySwatch =
      MaterialColor(0xFF3B82F6, <int, Color>{
        50: Color(0xFFEFF6FF),
        100: Color(0xFFDBEAFE),
        200: Color(0xFFBFDBFE),
        300: Color(0xFF93C5FD),
        400: Color(0xFF60A5FA),
        500: Color(0xFF3B82F6),
        600: Color(0xFF2563EB),
        700: Color(0xFF1D4ED8),
        800: Color(0xFF1E40AF),
        900: Color(0xFF1E3A8A),
      });
}

/// 2) Color roles (centralizes mapping → Material ColorScheme)
class AppColors {
  static ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.primaryBlue,
    onPrimary: Colors.white,
    secondary: AppPalette.primaryGreen,
    onSecondary: Colors.white,
    tertiary: AppPalette.tint100,
    onTertiary: AppPalette.gray900,
    surface: Colors.white,
    onSurface: AppPalette.gray900,
    onSurfaceVariant: AppPalette.gray700,
    error: AppPalette.danger,
    onError: Colors.white,
    outline: AppPalette.gray200,
    outlineVariant: AppPalette.gray100,
    shadow: Colors.black12,
    scrim: Colors.black54,
    inverseSurface: AppPalette.gray900,
    onInverseSurface: Colors.white,
    inversePrimary: AppPalette.primaryGreen,
  );

  static ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: const Color(0xFF60A5FA),
    onPrimary: AppPalette.gray900,
    secondary: const Color(0xFF34D399),
    onSecondary: AppPalette.gray900,
    tertiary: const Color(0xFF9AA5FF),
    onTertiary: AppPalette.gray900,
    surface: const Color(0xFF0F172A),
    onSurface: Colors.white,
    onSurfaceVariant: AppPalette.gray200,
    error: const Color(0xFFF87171),
    onError: AppPalette.gray900,
    outline: const Color(0xFF334155),
    outlineVariant: const Color(0xFF1F2937),
    shadow: Colors.black26,
    scrim: Colors.black54,
    inverseSurface: Colors.white,
    onInverseSurface: AppPalette.gray900,
    inversePrimary: AppPalette.primaryBlue,
  );
}

/// 3) Theme factory
class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: AppColors.lightScheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightScheme.surface,
      foregroundColor: AppColors.lightScheme.onSurface,
      elevation: 0,
    ),
    cardColor: AppColors.lightScheme.surface,
    dividerColor: AppPalette.gray200,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppPalette.gray900,
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.lightScheme.primary,
        foregroundColor: AppColors.lightScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: AppPalette.gray200),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.lightScheme.primary,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    colorScheme: AppColors.darkScheme,
    scaffoldBackgroundColor: AppColors.darkScheme.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkScheme.surface,
      foregroundColor: AppColors.darkScheme.onSurface,
      elevation: 0,
    ),
    cardColor: AppColors.darkScheme.surface,
    dividerColor: AppColors.darkScheme.outline,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.darkScheme.primary,
        foregroundColor: AppColors.darkScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.darkScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.darkScheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}

/// 4) Nice-to-have: semantic helpers
extension SemanticColors on ColorScheme {
  Color get danger => AppPalette.danger;
  Color get warning => AppPalette.warning;
  Color get success => AppPalette.success;
  Color get info => AppPalette.info;

  // Grays
  Color get g50 => AppPalette.gray50;
  Color get g100 => AppPalette.gray100;
  Color get g200 => AppPalette.gray200;
  Color get g400 => AppPalette.gray400;
  Color get g500 => AppPalette.gray500;
  Color get g700 => AppPalette.gray700;
  Color get g900 => AppPalette.gray900;
}
