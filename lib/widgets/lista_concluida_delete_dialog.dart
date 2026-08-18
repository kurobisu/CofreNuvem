import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';

/// Confirmação de 3 etapas pra excluir uma lista já concluída -- uma a mais
/// que o padrão de 2 etapas usado pra listas ativas, porque excluir uma
/// lista concluída também exclui a Transação financeira vinculada a ela
/// (ver [ListasComprasRepo.excluirConcluida]). A 3ª etapa é o lugar onde
/// esse impacto financeiro fica explícito antes da exclusão acontecer.
Future<bool> confirmarExclusaoListaConcluida(
  BuildContext context, {
  required String nomeLista,
  double? valorTransacao,
}) async {
  final etapa1 = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Excluir "$nomeLista"?'),
      content: const Text('Todos os itens dessa lista serão excluídos junto.'),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: AppColors.secondaryButtonStyle(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  if (etapa1 != true || !context.mounted) return false;

  final etapa2 = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Tem certeza?'),
      content: const Text('Essa ação não pode ser desfeita.'),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: AppColors.secondaryButtonStyle(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Excluir Definitivamente'),
        ),
      ],
    ),
  );
  if (etapa2 != true || !context.mounted) return false;

  final etapa3 = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Última confirmação'),
      content: Text(
        valorTransacao != null
            ? 'Essa lista está vinculada a uma transação de ${CurrencyFormatter.format(valorTransacao)} no seu Histórico Financeiro. Excluir a lista também vai excluir essa transação.'
            : 'Essa lista já foi concluída. Confirma a exclusão definitiva?',
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: AppColors.secondaryButtonStyle(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Excluir Definitivamente'),
        ),
      ],
    ),
  );
  return etapa3 == true;
}
