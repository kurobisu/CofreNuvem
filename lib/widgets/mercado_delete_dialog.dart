import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Confirmação de 3 etapas pra excluir um mercado -- todo mercado que
/// aparece em "Gerenciar mercados" já tem pelo menos uma lista usando ele
/// (é assim que ele existe), então a exclusão sempre tem dados reais em
/// jogo. A 3ª etapa deixa explícito o número de listas afetadas e que os
/// dados delas (itens, preços, transações, Relatórios) continuam intactos
/// -- só o vínculo com este mercado é removido, viram "sem mercado
/// definido" (ver [ListasComprasRepo.excluirMercado]).
Future<bool> confirmarExclusaoMercado(
  BuildContext context, {
  required String nomeMercado,
  required int quantidadeListas,
}) async {
  final etapa1 = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Excluir "$nomeMercado"?'),
      content: Text(
        quantidadeListas == 1
            ? '1 lista está marcada com este mercado.'
            : '$quantidadeListas listas estão marcadas com este mercado.',
      ),
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
      content: const Text(
        'As listas, itens, preços e transações continuam existindo -- só '
        'deixam de ter um mercado definido.',
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
          child: const Text('Continuar'),
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
        'Remover "$nomeMercado" definitivamente das ${quantidadeListas == 1 ? 'lista afetada' : 'listas afetadas'}? '
        'Nenhum dado de compra é apagado -- só o nome do mercado.',
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
