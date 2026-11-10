import 'package:flutter/material.dart';

abstract final class KataTokens {
  static const rust = Color(0xFFA34223);
  static const cream = Color(0xFFFFF8EF);
  static const charcoal = Color(0xFF24282B);
  static const teal = Color(0xFF006A68);
  static const gap = 16.0;
  static const radius = 24.0;
  static const maxContentWidth = 760.0;
  static ThemeData theme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: rust,
      brightness: brightness,
      secondary: brightness == Brightness.light
          ? teal
          : const Color(0xFF86D5D0),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? cream
          : charcoal,
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
