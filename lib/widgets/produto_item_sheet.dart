import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/supabase_helper.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/app_colors.dart';

const _unidades = ['Unidade', 'Kg', 'Litro'];

double _parseCurrency(String text) {
  final str = text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
  return double.tryParse(str) ?? 0;
}

/// Bottom sheet de adicionar/editar um item da lista, com autocomplete
/// contra o catálogo de produtos. Retorna true se salvou algo.
///
/// [produtoInicial] pré-preenche o formulário a partir de um produto do
/// catálogo (ex: veio do botão "+" numa tela de categoria) sem que isso
/// vire uma edição -- o Salvar continua criando um item novo.
Future<bool> showProdutoItemSheet(
  BuildContext context, {
  required String listaId,
  Map<String, dynamic>? itemExistente,
  Map<String, dynamic>? produtoInicial,
}) async {
  final supabase = SupabaseHelper.instance.client;

  final nomeInicial = (itemExistente?['nome'] ?? produtoInicial?['nome'] ?? '').toString();
  final buscaController = TextEditingController(text: nomeInicial);
  final precoUnitController = TextEditingController();
  final totalController = TextEditingController();
  final qtdeController = TextEditingController(text: '1');

  String unidade = (itemExistente?['unidade'] ?? produtoInicial?['unidade_padrao'] ?? 'Unidade').toString();
  String emoji = (produtoInicial?['emoji'] ?? '🛒').toString();
  String? produtoId = (itemExistente?['produto_id'] ?? produtoInicial?['id'])?.toString();
  double? precoAnterior;
  List<Map<String, dynamic>> sugestoes = [];
  bool salvou = false;

  final qtdeInicial = ((itemExistente?['quantidade'] ?? 1) as num?)?.toDouble() ?? 1.0;
  qtdeController.text = unidade == 'Unidade' ? qtdeInicial.round().toString() : qtdeInicial.toString();
  final precoInicial = ((itemExistente?['preco'] ?? 0) as num?)?.toDouble() ?? 0.0;
  if (precoInicial > 0) precoUnitController.text = CurrencyFormatter.format(precoInicial);

  Future<Map<String, dynamic>?> buscarEmojiEHistorico(String pid) async {
    try {
      final prod = await supabase.from(SupabaseHelper.tableProdutosCatalogo).select().eq('id', pid).maybeSingle();
      Map<String, dynamic>? hist;
      final histRaw = await supabase
          .from(SupabaseHelper.tableListaCompras)
          .select('preco, updated_at')
          .eq('produto_id', pid)
          .neq('lista_id', listaId)
          .not('preco', 'is', null)
          .filter('deleted_at', 'is', null)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      hist = histRaw;
      return {'produto': prod, 'historico': hist};
    } catch (_) {
      return null;
    }
  }

  // Se veio de um produto do catálogo, já busca o último preço pago antes
  // de abrir a folha, pra já nascer preenchido.
  if (produtoId != null && itemExistente == null) {
    final extra = await buscarEmojiEHistorico(produtoId);
    final hist = extra?['historico'] as Map<String, dynamic>?;
    if (hist != null) precoAnterior = ((hist['preco'] ?? 0) as num).toDouble();
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          void recalcularTotal() {
            final unit = _parseCurrency(precoUnitController.text);
            final qtde = double.tryParse(qtdeController.text.replaceAll(',', '.')) ?? 1.0;
            final total = unit * qtde;
            totalController.text = total > 0 ? CurrencyFormatter.format(total) : '';
          }

          Future<void> buscar(String query) async {
            if (query.trim().length < 2) {
              setModalState(() => sugestoes = []);
              return;
            }
            final raw = await supabase
                .from(SupabaseHelper.tableProdutosCatalogo)
                .select()
                .ilike('nome', '%${query.trim()}%')
                .filter('deleted_at', 'is', null)
                .order('nome', ascending: true)
                .limit(4);
            setModalState(() => sugestoes = raw.map((e) => CaseInsensitiveMap(e as Map<String, dynamic>)).cast<Map<String, dynamic>>().toList());
          }

          Future<void> selecionar(Map<String, dynamic> produto) async {
            produtoId = produto['id'].toString();
            buscaController.text = produto['nome'].toString();
            emoji = (produto['emoji'] ?? '🛒').toString();
            unidade = (produto['unidade_padrao'] ?? 'Unidade').toString();
            qtdeController.text = unidade == 'Unidade' ? '1' : '1';
            sugestoes = [];
            setModalState(() {});

            final extra = await buscarEmojiEHistorico(produtoId!);
            final hist = extra?['historico'] as Map<String, dynamic>?;
            if (hist != null) {
              precoAnterior = ((hist['preco'] ?? 0) as num).toDouble();
            }
            setModalState(() {});
          }

          void alterarQuantidade(double delta) {
            final atual = double.tryParse(qtdeController.text.replaceAll(',', '.')) ?? 1.0;
            var novo = atual + delta;
            if (novo < (unidade == 'Unidade' ? 1 : 0.1)) novo = unidade == 'Unidade' ? 1 : 0.1;
            qtdeController.text = unidade == 'Unidade' ? novo.round().toString() : novo.toStringAsFixed(1);
            recalcularTotal();
            setModalState(() {});
          }

          final nomeAtual = buscaController.text.trim();
          Widget historicoWidget = const SizedBox.shrink();
          if (precoAnterior != null && precoAnterior! > 0) {
            final atual = _parseCurrency(precoUnitController.text);
            if (atual > 0) {
              final diff = atual - precoAnterior!;
              if (diff.abs() >= 0.01) {
                final pct = (diff / precoAnterior!) * 100;
                historicoWidget = Text(
                  '${diff > 0 ? '+' : '-'} ${CurrencyFormatter.format(diff.abs())} (${diff > 0 ? '+' : '-'}${pct.abs().toStringAsFixed(1)}%) vs último preço (${CurrencyFormatter.format(precoAnterior!)})',
                  style: TextStyle(color: diff > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }
            } else {
              historicoWidget = Text(
                'Último preço: ${CurrencyFormatter.format(precoAnterior!)}',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
              );
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider(context), borderRadius: BorderRadius.circular(4)))),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                          Text(itemExistente == null ? 'Novo Item' : 'Editar Item', style: const TextStyle(fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: nomeAtual.isEmpty
                                ? null
                                : () async {
                                    final unit = _parseCurrency(precoUnitController.text);
                                    final qtde = double.tryParse(qtdeController.text.replaceAll(',', '.')) ?? 1.0;
                                    final db = await SupabaseHelper.instance.database;
                                    final data = {
                                      'nome': nomeAtual,
                                      'produto_id': produtoId,
                                      'unidade': unidade,
                                      'quantidade': qtde,
                                      'preco': unit > 0 ? unit : null,
                                      'lista_id': listaId,
                                    };
                                    if (itemExistente == null) {
                                      await db.insert(SupabaseHelper.tableListaCompras, data);
                                    } else {
                                      await db.update(SupabaseHelper.tableListaCompras, data, where: 'id = ?', whereArgs: [itemExistente['id']]);
                                    }
                                    salvou = true;
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                            child: const Text('Salvar', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: buscaController,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Nome do produto'),
                                textCapitalization: TextCapitalization.sentences,
                                onChanged: (v) {
                                  produtoId = null;
                                  precoAnterior = null;
                                  buscar(v);
                                },
                              ),
                            ),
                            CircleAvatar(backgroundColor: Colors.black26, radius: 20, child: Text(emoji, style: const TextStyle(fontSize: 20))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: precoUnitController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                              decoration: InputDecoration(labelText: 'Preço', filled: true, fillColor: Theme.of(context).cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                              onChanged: (_) => setModalState(recalcularTotal),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: IgnorePointer(
                              child: TextField(
                                controller: totalController,
                                decoration: InputDecoration(labelText: 'Total', filled: true, fillColor: Theme.of(context).cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (historicoWidget is! SizedBox) Padding(padding: const EdgeInsets.only(top: 8), child: historicoWidget),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: unidade,
                              decoration: InputDecoration(labelText: 'Unidade', filled: true, fillColor: Theme.of(context).cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                              items: _unidades.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (v) {
                                setModalState(() {
                                  unidade = v!;
                                  qtdeController.text = unidade == 'Unidade' ? '1' : '1.0';
                                  recalcularTotal();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: qtdeController,
                              keyboardType: TextInputType.numberWithOptions(decimal: unidade != 'Unidade'),
                              inputFormatters: unidade == 'Unidade' ? [FilteringTextInputFormatter.digitsOnly] : null,
                              decoration: InputDecoration(labelText: 'Quantidade', filled: true, fillColor: Theme.of(context).cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                              onChanged: (_) => setModalState(recalcularTotal),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              Row(
                                children: [
                                  _qtdeBtn(context, Icons.remove, () => alterarQuantidade(unidade == 'Unidade' ? -1 : -0.5)),
                                  const SizedBox(width: 6),
                                  _qtdeBtn(context, Icons.add, () => alterarQuantidade(unidade == 'Unidade' ? 1 : 0.5)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (sugestoes.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: sugestoes.map((s) {
                              return ListTile(
                                leading: CircleAvatar(backgroundColor: Colors.black26, child: Text((s['emoji'] ?? '🛒').toString())),
                                title: Text(s['nome'].toString()),
                                onTap: () => selecionar(s),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  return salvou;
}

Widget _qtdeBtn(BuildContext context, IconData icon, VoidCallback onTap) {
  return InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: Colors.white),
    ),
  );
}
