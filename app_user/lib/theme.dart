import 'package:flutter/material.dart';

/// Farb-/Formsprache angelehnt an das Mockup-Designsystem
/// "Craft-Trade ERP System" (siehe ~/git/saasERP/mockup).
ThemeData buildAppTheme() {
  const deepNavy = Color(0xFF091426);
  const steelBlue = Color(0xFF4A607E);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: deepNavy,
    primary: deepNavy,
    secondary: steelBlue,
    surface: const Color(0xFFF8FAFB),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: deepNavy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
    ),
  );
}
