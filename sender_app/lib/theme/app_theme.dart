import 'package:flutter/material.dart';

/// WinzoWin Design System — centralized color palette, typography & theme tokens.
/// All UI components should reference these constants for visual consistency.
class WinzoColors {
  WinzoColors._();

  // ── Brand Primaries ──────────────────────────────────────────────────────
  static const Color primary = Color(0xFF7C3AED); // Deep violet
  static const Color primaryLight = Color(0xFF9D5CF6); // Lighter violet
  static const Color primaryGlow = Color(0xFF8B5CF6); // Soft violet glow

  // ── Accent / Secondary ───────────────────────────────────────────────────
  static const Color accent = Color(0xFF06B6D4); // Cyan
  static const Color accentAlt = Color(0xFF38BDF8); // Sky blue highlight

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981); // Emerald green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  static const Color errorSoft = Color(0xFFFCA5A5);

  // ── Backgrounds / Surfaces ───────────────────────────────────────────────
  static const Color bgDeep = Color(0xFF060B14); // Deepest background
  static const Color bgBase = Color(0xFF0A0F1E); // Main scaffold background
  static const Color bgSurface = Color(0xFF111827); // Card surface
  static const Color bgElevated = Color(0xFF1A2236); // Elevated surface
  static const Color bgSeparator = Color(0xFF1E293B); // Divider / border

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF1F5F9); // Primary text
  static const Color textSecondary = Color(0xFF94A3B8); // Secondary text
  static const Color textMuted = Color(0xFF64748B); // Muted / tertiary text
  static const Color textOnDark = Colors.white;

  // ── Borders ──────────────────────────────────────────────────────────────
  static const Color borderSubtle = Color(0xFF1E293B);
  static const Color borderPrimary = Color(0xFF7C3AED);
}

class WinzoDimens {
  WinzoDimens._();
  static const double radiusXS = 8.0;
  static const double radiusSM = 12.0;
  static const double radiusMD = 16.0;
  static const double radiusLG = 20.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 999.0;

  static const double spaceXXS = 4.0;
  static const double spaceXS = 8.0;
  static const double spaceSM = 12.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 20.0;
  static const double spaceXL = 24.0;
  static const double spaceXXL = 32.0;
}

class WinzoTheme {
  WinzoTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: WinzoColors.bgBase,
      colorScheme: const ColorScheme.dark(
        primary: WinzoColors.primary,
        secondary: WinzoColors.accent,
        surface: WinzoColors.bgSurface,
        error: WinzoColors.error,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: WinzoColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: WinzoColors.textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: WinzoColors.textPrimary,
          letterSpacing: 0.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: WinzoColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: WinzoColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: WinzoColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: WinzoColors.textSecondary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: WinzoColors.textSecondary,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: WinzoColors.textMuted,
          letterSpacing: 0.2,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: WinzoColors.textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: WinzoColors.bgDeep,
        indicatorColor: WinzoColors.primary.withAlpha(55),
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: WinzoColors.primaryLight,
              letterSpacing: 0.3,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: WinzoColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: WinzoColors.primaryLight, size: 24);
          }
          return const IconThemeData(color: WinzoColors.textMuted, size: 22);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: WinzoColors.primary,
          foregroundColor: WinzoColors.textOnDark,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
          ),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: WinzoColors.bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WinzoDimens.radiusLG),
          side: const BorderSide(color: WinzoColors.borderSubtle),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: WinzoColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
