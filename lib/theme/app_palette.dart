// lib/theme/app_palette.dart
import 'package:flutter/material.dart';

/// Colours of the 2026 redesign (see docs/design/home-*.png).
///
/// Accents (lime, coral, blue, teal) are the same in both modes; only
/// backgrounds, surfaces and text change. In light mode lime is a background
/// colour only, never a text colour (it's unreadable on white).
///
/// Use `AppPalette.of(context)` in widgets.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.limeSoft,
    required this.navBar,
    required this.navIcon,
  });

  // ---- Accents (same in both modes) ----
  static const Color ink = Color(0xFF0D171B);
  static const Color lime = Color(0xFFC6F432);
  static const Color coral = Color(0xFFFF8A5B);
  static const Color blue = Color(0xFF8AB4FF);
  static const Color teal = Color(0xFF58B8B6);
  static const Color peach = Color(0xFFFFC2A6);

  /// Text/icons on lime, coral, blue or teal backgrounds.
  static const Color onAccent = ink;

  /// Page background.
  final Color background;

  /// Cards and rows.
  final Color surface;

  /// Subtle fills: map card, round icon buttons, day strip.
  final Color surfaceMuted;

  /// Hairline borders around cards.
  final Color border;

  final Color text;

  /// Secondary text ("Ilidža · 9 going").
  final Color textMuted;

  /// Soft lime fill (e.g. the avatar circle in light mode).
  final Color limeSoft;

  /// Floating bottom bar (dark in both modes).
  final Color navBar;
  final Color navIcon;

  static const AppPalette light = AppPalette(
    background: Color(0xFFF4F7F5),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFE6EEEC),
    border: Color(0xFFE2E9E6),
    text: ink,
    textMuted: Color(0xFF5B6E73),
    limeSoft: Color(0xFFE8F7C2),
    navBar: ink,
    navIcon: Color(0xFFB8C7CB),
  );

  static const AppPalette dark = AppPalette(
    background: ink,
    surface: Color(0xFF142228),
    surfaceMuted: Color(0xFF1B2E35),
    border: Color(0xFF213239),
    text: Color(0xFFF2F5F3),
    // Brighter than the mock-up's grey for readability on dark cards.
    textMuted: Color(0xFFA9BCC1),
    limeSoft: Color(0xFF243B35),
    navBar: Color(0xFF17262C),
    navIcon: Color(0xFFB8C7CB),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? limeSoft,
    Color? navBar,
    Color? navIcon,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      limeSoft: limeSoft ?? this.limeSoft,
      navBar: navBar ?? this.navBar,
      navIcon: navIcon ?? this.navIcon,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      limeSoft: Color.lerp(limeSoft, other.limeSoft, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      navIcon: Color.lerp(navIcon, other.navIcon, t)!,
    );
  }
}

/// Spacing and shape scale.
class AppSpace {
  AppSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Side padding of a page.
  static const double page = 20;

  static const double radiusCard = 24;
  static const double radiusChip = 16;
  static const double radiusPill = 999;
}
