// ─────────────────────────────────────────────────────────────────────────────
// THEME — light and dark, one palette, no purple gradients.
//
// The premium look from the mockup, as code: generous spacing, 20px rounded
// cards, soft shadows, one clear accent per meaning:
//   emerald  = done / productive / "go"
//   amber    = warning / wasted time / XP
//   sky      = information / links
//   rose     = blocked / over the limit
// Dark mode is true dark (near-black background, elevated cards), light mode
// is clean white cards on a soft grey background.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

class AppTheme {
  static const emerald = Color(0xFF059669);
  static const emeraldSoft = Color(0xFFD1FAE5);
  static const amber = Color(0xFFD97706);
  static const amberSoft = Color(0xFFFEF3C7);
  static const sky = Color(0xFF0284C7);
  static const skySoft = Color(0xFFE0F2FE);
  static const rose = Color(0xFFE11D48);
  static const roseSoft = Color(0xFFFFE4E6);

  static const _radius = 20.0;

  static ThemeData light() {
    const background = Color(0xFFF6F7F9);
    const surface = Colors.white;
    const text = Color(0xFF111827);
    const muted = Color(0xFF6B7280);
    return _build(
      brightness: Brightness.light,
      background: background,
      surface: surface,
      text: text,
      muted: muted,
      shadow: Colors.black.withValues(alpha: 0.06),
    );
  }

  static ThemeData dark() {
    const background = Color(0xFF0B0F14);
    const surface = Color(0xFF151B23);
    const text = Color(0xFFF3F4F6);
    const muted = Color(0xFF9CA3AF);
    return _build(
      brightness: Brightness.dark,
      background: background,
      surface: surface,
      text: text,
      muted: muted,
      shadow: Colors.black.withValues(alpha: 0.35),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color text,
    required Color muted,
    required Color shadow,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: brightness,
      primary: emerald,
      secondary: sky,
      tertiary: amber,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ).apply(bodyColor: text, displayColor: text),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: text,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: muted.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: muted.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: emerald, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: emerald,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Soft shadow used under cards for the "lifted" premium feel.
  static List<BoxShadow> cardShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.07),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }
}
