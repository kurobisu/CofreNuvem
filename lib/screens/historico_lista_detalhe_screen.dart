import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/listas_compras_provider.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';

/// Visualização somente-leitura dos itens de uma lista já concluída --
/// sem checkbox tocável, sem edição, sem "Finalizar compra" de novo.
class HistoricoListaDetalheScreen extends ConsumerWidget {
  final String listaId;
  final String nomeLista;

  const HistoricoListaDetalheScreen({super.key, required this.listaId, required this.nomeLista});

  double _num(dynamic v, [double fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  bool _isMarcado(Map<String, dynamic> item) => item['comprado'] == 1 || item['comprado'] == true;

  Widget _itemTile(BuildContext context, Map<String, dynamic> item, bool marcado) {
    final nome = (item['nome'] ?? '').toString();
    final preco = _num(item['preco']);
    final qtde = _num(item['quantidade'], 1.0);
    final unidade = (item['unidade'] ?? 'Unidade').toString();
    final total = preco * qtde;

    String? qtdeLabel;
    if (unidade == 'Unidade') {
      if (qtde != 1) qtdeLabel = qtde.round().toString();
    } else {
      final qtdeStr = qtde % 1 == 0 ? qtde.toStringAsFixed(0) : qtde.toString();
      qtdeLabel = '$qtdeStr $unidade';
    }

    return ListTile(
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: marcado ? Colors.green : Colors.transparent,
          border: Border.all(color: marcado ? Colors.green : Colors.blueAccent, width: 2),
        ),
        child: marcado ? const Icon(Icons.check, size: 18, color: Colors.black) : null,
      ),
      title: Text(
        nome,
        style: TextStyle(color: marcado ? Colors.white38 : Colors.white, decoration: marcado ? TextDecoration.lineThrough : null),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (qtdeLabel != null) Padding(padding: const EdgeInsets.only(right: 8), child: Text(qtdeLabel, style: TextStyle(color: AppColors.secondaryText(context)))),
          Text(total > 0 ? CurrencyFormatter.format(total) : '-', style: TextStyle(color: marcado ? Colors.white38 : Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itensAsync = ref.watch(listaItensProvider(listaId));

    return Scaffold(
      appBar: AppBar(title: Text(nomeLista, overflow: TextOverflow.ellipsis)),
      body: itensAsync.when(
        data: (itens) {
          if (itens.isEmpty) {
            return Center(
              child: Text('Essa lista não tinha itens.', style: TextStyle(color: AppColors.secondaryText(context))),
            );
          }

          final comprados = itens.where(_isMarcado).toList();
          final naoComprados = itens.where((i) => !_isMarcado(i)).toList();
          double totalComprado = 0;
          for (final i in comprados) {
            totalComprado += _num(i['preco']) * _num(i['quantidade'], 1.0);
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    ...naoComprados.map((item) => _itemTile(context, item, false)),
                    if (comprados.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          'COMPRADOS (${comprados.length})',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryText(context)),
                        ),
                      ),
                      ...comprados.map((item) => _itemTile(context, item, true)),
                    ],
                  ],
                ),
              ),
              Container(
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Itens', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 12)),
                        Text('${comprados.length}/${itens.length} comprados', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total gasto', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 12)),
                        Text(CurrencyFormatter.format(totalComprado), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }
}
