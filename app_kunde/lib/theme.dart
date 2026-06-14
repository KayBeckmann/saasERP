import 'package:flutter/material.dart';

/// Primärfarben des Mockup-Designsystems "Warm Enterprise Portal" (siehe
/// ~/git/saasERP/mockup/warm_enterprise_portal/DESIGN.md) — anders als das
/// "Craft-Trade ERP System" der User-App, bewusst wärmer/runder für
/// Endkunden.
const warmTeal = Color(0xFF0D9488);
const slateSecondary = Color(0xFF565E74);

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
/// "Warm Enterprise Portal" (siehe ~/git/saasERP/mockup).
///
/// [primaryColor] kommt aus dem Branding des einladenden Mandanten
/// (Whitelabel-Potenzial) — `null` fällt auf das generische Theme zurück.
ThemeData buildAppTheme({Color? primaryColor}) {
  final primary = primaryColor ?? warmTeal;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    primary: primary,
    secondary: slateSecondary,
    surface: const Color(0xFFF8FAFC),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
  );
}
