import 'package:flutter/material.dart';

/// Palette lifted from the original Android project's colors.xml so the
/// Flutter app keeps the same saffron/maroon/gold "temple" look.
class AppColors {
  static const saffron = Color(0xFFFF9933);
  static const saffronDark = Color(0xFFE07C1A);
  static const deepMaroon = Color(0xFF4A1010);
  static const cream = Color(0xFFFFF8ED);
  static const ink = Color(0xFF22160B);
  static const gold = Color(0xFFD4AF37);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.cream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.saffron,
      primary: AppColors.saffron,
      secondary: AppColors.gold,
      surface: AppColors.cream,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.saffronDark,
      foregroundColor: AppColors.cream,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.saffron
            : AppColors.cream,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.saffronDark
            : Colors.grey.shade400,
      ),
    ),
    textTheme: const TextTheme().apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
  );
}
