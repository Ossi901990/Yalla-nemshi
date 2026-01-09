import 'package:flutter/material.dart';

extension ColorUtils on Color {
  /// Safe replacement for `withOpacity` that avoids deprecated API.
  /// Preserves the original `withOpacity` behavior by setting the alpha
  /// to `(opacity * 255).round()`.
  Color withOpacitySafe(double opacity) => withAlpha((opacity * 255).round());
}
