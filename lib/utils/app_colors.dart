import 'package:flutter/material.dart';

/// Theme-aware color helpers for better light/dark contrast.
class AppColors {
  AppColors._();

  /// Secondary text color that is readable on both light and dark surfaces.
  static Color secondaryText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey.shade400 : Colors.grey.shade700;
  }

  /// Tertiary/muted text (labels, hints, captions).
  static Color mutedText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey.shade500 : Colors.grey.shade600;
  }

  /// Divider and border color.
  static Color divider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey.shade800 : Colors.grey.shade300;
  }

  /// Color for icons in list tiles / app bars that need subtle emphasis.
  static Color iconMuted(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey.shade500 : Colors.grey.shade600;
  }

  /// Text color that contrasts with the current surface (card/scaffold).
  static Color onSurface(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }
}
