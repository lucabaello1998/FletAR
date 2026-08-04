import 'package:flutter/material.dart';

import 'fletar_colors.dart';

abstract final class FletarTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: FletarColors.primary,
      brightness: Brightness.light,
      primary: FletarColors.primary,
      secondary: FletarColors.secondary,
      surface: FletarColors.surface,
      error: FletarColors.destructive,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: FletarColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: FletarColors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FletarColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FletarColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FletarColors.border),
        ),
      ),
    );
  }
}
