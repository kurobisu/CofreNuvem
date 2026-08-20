import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Ícone "?" que abre uma explicação curta com um **exemplo concreto**.
///
/// Alguns campos de formulário (ex.: "Preço" que na verdade é por Kg/Litro,
/// não o total) são óbvios pra quem montou o app e opacos pra quem só usa.
/// Um `helperText` cinza embaixo do campo passa despercebido; um "?"
/// clicável ao lado do campo é percebido e só ocupa espaço quando o usuário
/// quer.
///
/// Use como `suffixIcon`/`prefixIcon` de um campo ou solto ao lado de um
/// rótulo (ver [LabelWithHelp]).
class HelpIconButton extends StatelessWidget {
  const HelpIconButton({
    super.key,
    required this.title,
    required this.explanation,
    this.example,
  });

  final String title;
  final String explanation;

  /// Exemplo concreto, mostrado em destaque (ex.: "1,83 Kg comprados").
  final String? example;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline, size: 20),
      tooltip: 'O que é isso?',
      visualDensity: VisualDensity.compact,
      color: AppColors.iconMuted(context),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(explanation),
              if (example != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    example!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rótulo de seção com o "?" ao lado -- pra grupos de campos que não são um
/// campo de texto só (ex.: unidade + quantidade juntos).
class LabelWithHelp extends StatelessWidget {
  const LabelWithHelp({
    super.key,
    required this.label,
    required this.title,
    required this.explanation,
    this.example,
  });

  final String label;
  final String title;
  final String explanation;
  final String? example;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondaryText(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        HelpIconButton(title: title, explanation: explanation, example: example),
      ],
    );
  }
}
