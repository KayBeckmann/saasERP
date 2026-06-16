import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Primärfarben des Mockup-Designsystems "Craft-Trade ERP System"
const deepNavy = Color(0xFF091426);
const steelBlue = Color(0xFF4A607E);

// Farbtokens aus DESIGN.md
const colorSurface = Color(0xFFF8FAFB);
const colorSurfaceContainerLowest = Color(0xFFFFFFFF);
const colorSurfaceContainerLow = Color(0xFFF2F4F5);
const colorSurfaceContainerHigh = Color(0xFFE6E8E9);
const colorOnSurface = Color(0xFF191C1D);
const colorOnSurfaceVariant = Color(0xFF45474C);
const colorOutlineVariant = Color(0xFFC5C6CD);
const colorOutline = Color(0xFF75777D);

Color? parseBrandingColor(String? hex) {
  if (hex == null) return null;
  final match = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(hex);
  if (match == null) return null;
  return Color(int.parse(match.group(1)!, radix: 16) | 0xFF000000);
}

ThemeData buildAppTheme({Color? primaryColor}) {
  final primary = primaryColor ?? deepNavy;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    primary: primary,
    onPrimary: Colors.white,
    secondary: steelBlue,
    surface: colorSurface,
    onSurface: colorOnSurface,
    onSurfaceVariant: colorOnSurfaceVariant,
    outline: colorOutline,
    outlineVariant: colorOutlineVariant,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorSurface,
  );

  final inter = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    displayLarge: GoogleFonts.inter(fontSize: 57, fontWeight: FontWeight.w600, letterSpacing: -0.25),
    headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w600, height: 1.25),
    headlineMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w500),
    titleLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w500),
    titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15),
    bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
    bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
    labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
    labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
  );

  return base.copyWith(
    textTheme: inter,
    primaryTextTheme: GoogleFonts.interTextTheme(base.primaryTextTheme),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: colorOutlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: colorOutlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: steelBlue,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
        side: const BorderSide(color: steelBlue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: steelBlue,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: colorSurfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: colorOutlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: colorOutlineVariant, thickness: 1),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colorOnSurface,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorSurfaceContainerLowest,
      foregroundColor: colorOnSurface,
      elevation: 0,
      titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: colorOnSurface),
    ),
  );
}
