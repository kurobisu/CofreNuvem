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

  /// Estilo de botão de ação primária (Salvar/Criar/Confirmar) usado em
  /// folhas e diálogos: preenchido com a cor de destaque do app, bem
  /// contrastado contra fundos escuros.
  static ButtonStyle primaryButtonStyle(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ElevatedButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: primary.withOpacity(0.35),
      disabledForegroundColor: Colors.white70,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  /// Estilo de botão de ação secundária (Cancelar) usado em folhas e
  /// diálogos: com borda visível, já que texto solto sem contorno se perde
  /// contra o fundo escuro dessas janelas.
  static ButtonStyle secondaryButtonStyle(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: onSurface(context),
      side: BorderSide(color: divider(context), width: 1.4),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }
}
