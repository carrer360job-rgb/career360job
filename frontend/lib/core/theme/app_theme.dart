import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Career360 Corporate Blue Design System & Theme
class AppTheme {
  // Official Client Color Palette (Corporate Blue)
  static const Color primary = Color(0xFF155EEF);      // Corporate Blue (#155EEF)
  static const Color primaryDark = Color(0xFF0B1F3A);  // Deep Midnight Navy (#0B1F3A)
  static const Color accent = Color(0xFF38BDF8);       // Sky Blue / Cyan Accent (#38BDF8)
  static const Color background = Color(0xFFF8FAFC);   // Background Canvas (#F8FAFC)
  static const Color cardSurface = Color(0xFFFFFFFF);  // Pure White (#FFFFFF)
  static const Color textPrimary = Color(0xFF172B4D);  // Main Text & Headings (#172B4D)
  static const Color textSecondary = Color(0xFF64748B);// Muted Subtitles (#64748B)

  // Functional Colors
  static const Color border = Color(0xFFE2E8F0);       // Clean Border (#E2E8F0)
  static const Color primaryLight = Color(0xFFEFF8FF); // Soft Blue Tint (#EFF8FF)
  static const Color success = Color(0xFF16A34A);      // Success / Verified Green (#16A34A)
  static const Color warning = Color(0xFFF59E0B);      // Warning Amber (#F59E0B)
  static const Color error = Color(0xFFDC2626);        // Error Crimson (#DC2626)

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: cardSurface,
      error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: cardSurface,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: cardSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
