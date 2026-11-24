// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Text styles of the 2026 redesign.
///
/// Headlines use Bricolage Grotesque (a variable font, so the weight is set
/// with a font variation); everything else uses Inter.
class AppText {
  AppText._();

  static TextStyle display(
    double size, {
    Color? color,
    double weight = 800,
    double height = 1.02,
  }) {
    return TextStyle(
      fontFamily: 'Bricolage',
      fontSize: size,
      height: height,
      letterSpacing: -0.03 * size,
      color: color,
      fontVariations: [FontVariation('wght', weight)],
      fontWeight: weight >= 700 ? FontWeight.w800 : FontWeight.w600,
    );
  }

  static TextStyle body(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w500,
    double height = 1.35,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      height: height,
      fontWeight: weight,
      color: color,
    );
  }
}

/// App-wide [ThemeData] for light and dark mode.
///
/// Text sizes are kept from the previous theme so screens that haven't been
/// redesigned yet keep their layout; colours come from [AppPalette].
class AppTheme {
  AppTheme._();

  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final p = isDark ? AppPalette.dark : AppPalette.light;

    final scheme = ColorScheme(
      brightness: brightness,
      // Primary actions: ink buttons on light, lime buttons on dark.
      primary: isDark ? AppPalette.lime : AppPalette.ink,
      onPrimary: isDark ? AppPalette.ink : Colors.white,
      secondary: AppPalette.coral,
      onSecondary: AppPalette.ink,
      tertiary: AppPalette.blue,
      onTertiary: AppPalette.ink,
      error: const Color(0xFFE5484D),
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.textMuted,
      surfaceContainerHighest: p.surfaceMuted,
      outline: p.border,
      outlineVariant: p.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: p.background,
      cardColor: p.surface,
      dividerColor: p.border,
      extensions: [p],
    );

    return base.copyWith(
      textTheme: _textTheme.apply(bodyColor: p.text, displayColor: p.text),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppText.display(22, color: p.text, weight: 700),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.radiusCard),
          side: BorderSide(color: p.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: AppText.body(15, weight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? p.surfaceMuted : AppPalette.ink,
        contentTextStyle: AppText.body(14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // Same sizes as the previous theme (Poppins headings, Inter body).
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 32,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 28,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.3,
      height: 1.25,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 24,
      fontWeight: FontWeight.bold,
      height: 1.3,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      height: 1.5,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.5,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.5,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      letterSpacing: 0.15,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      letterSpacing: 0.25,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      letterSpacing: 0.4,
      height: 1.5,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.43,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.33,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.45,
    ),
  );
}
