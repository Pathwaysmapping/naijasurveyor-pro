import 'package:flutter/material.dart';

/// Design System for Pathways Mapping & NaijaSurveyor Pro
/// Brand Colors:
/// - Deep Midnight Navy: #070d18 / #0a1528
/// - Signature Crimson Red: #dc2626 / #ef4444
/// - Pure White & Slate: #ffffff / #f8fafc / #94a3b8
/// Clean, technical engineering aesthetic without decorative emojis.
class AppTheme {
  static const Color midnightNavy = Color(0xFF070D18);
  static const Color cardNavy = Color(0xFF0A1528);
  static const Color elevatedNavy = Color(0xFF131F37);
  static const Color strokeNavy = Color(0xFF1E293B);

  static const Color crimsonPrimary = Color(0xFFDC2626);
  static const Color crimsonAccent = Color(0xFFEF4444);

  static const Color slateText = Color(0xFF94A3B8);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color emeraldSuccess = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: midnightNavy,
      primaryColor: crimsonPrimary,
      canvasColor: midnightNavy,
      cardColor: cardNavy,
      colorScheme: const ColorScheme.dark(
        primary: crimsonPrimary,
        secondary: crimsonAccent,
        surface: cardNavy,
        background: midnightNavy,
        onPrimary: pureWhite,
        onSecondary: pureWhite,
        onSurface: pureWhite,
        onBackground: pureWhite,
        outline: strokeNavy,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: midnightNavy,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: pureWhite),
        titleTextStyle: TextStyle(
          color: pureWhite,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardNavy,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: strokeNavy, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: strokeNavy, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: crimsonPrimary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: slateText, fontSize: 13),
        hintStyle: const TextStyle(color: slateMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: crimsonPrimary,
          foregroundColor: pureWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pureWhite,
          side: const BorderSide(color: strokeNavy, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      dividerColor: strokeNavy,
    );
  }
}
