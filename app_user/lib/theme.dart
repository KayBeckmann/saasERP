import 'package:flutter/material.dart';

/// Primärfarben des Mockup-Designsystems "Craft-Trade ERP System", auch
/// für Layout-Komponenten (AppShell, StatusChip) außerhalb des Theme nutzbar.
const deepNavy = Color(0xFF091426);
const steelBlue = Color(0xFF4A607E);

/// Liest einen Hex-Code (`#RRGGBB`) aus dem Tenant-Branding. Gibt `null`
/// zurück, wenn kein/ein ungültiger Wert gesetzt ist — dann greift das
/// generische Theme.
Color? parseBrandingColor(String? hex) {
  if (hex == null) return null;
  final match = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(hex);
  if (match == null) return null;
  return Color(int.parse(match.group(1)!, radix: 16) | 0xFF000000);
}

/// Farb-/Formsprache angelehnt an das Mockup-Designsystem
/// "Craft-Trade ERP System" (siehe ~/git/saasERP/mockup).
///
/// [primaryColor] kommt aus dem Branding des aktuellen Mandanten
/// (Whitelabel-Potenzial) — `null` fällt auf das generische Theme zurück.
ThemeData buildAppTheme({Color? primaryColor}) {
  final primary = primaryColor ?? deepNavy;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    primary: primary,
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
        backgroundColor: primary,
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
