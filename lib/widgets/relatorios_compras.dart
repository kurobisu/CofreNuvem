import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';
import '../providers/listas_compras_provider.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';
import 'mercado_delete_dialog.dart';

/// Itens efetivamente comprados (comprado=1) em qualquer lista, com a
/// categoria do catálogo embutida -- base pra todos os relatórios desta
/// aba. Cobre o histórico acumulado (sem filtro de período por enquanto).
final _historicoComprasProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = SupabaseHelper.instance.client;
  const camposBase =
      'preco, quantidade, nome, produto_id, updated_at, produtos_catalogo(nome, emoji, categoria_id, categorias_produtos(nome, emoji))';
  List<dynamic> raw;
  try {
    // listas_compras.mercado pode não existir ainda (script
    // scripts/add_marca_e_mercado.sql não rodado) -- se o embed falhar,
    // cai pro select sem ele em vez de quebrar a aba de relatórios inteira.
    raw = await supabase
        .from(SupabaseHelper.tableListaCompras)
        .select('$camposBase, listas_compras(mercado)')
        .eq('comprado', 1)
        .filter('deleted_at', 'is', null);
  } catch (_) {
    raw = await supabase
        .from(SupabaseHelper.tableListaCompras)
        .select(camposBase)
        .eq('comprado', 1)
        .filter('deleted_at', 'is', null);
  }
  return raw
      .map((e) => CaseInsensitiveMap(e as Map<String, dynamic>))
      .cast<Map<String, dynamic>>()
      .toList();
});

const _paletaCores = [
  Color(0xFF10B981),
  Color(0xFF3B82F6),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFF97316),
  Color(0xFF06B6D4),
  Color(0xFF84CC16),
  Color(0xFF6366F1),
  Color(0xFFD946EF),
];

const _nomesMeses = [
  '',
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

double _num(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

/// Conteúdo da aba "Relatórios" dentro do Catálogo: categorias mais
/// compradas, produtos mais frequentes e gasto por mês -- tudo calculado
/// em cima dos itens já marcados como comprados em qualquer lista.
class ComprasRelatoriosTab extends ConsumerStatefulWidget {
  const ComprasRelatoriosTab({super.key});

  @override
  ConsumerState<ComprasRelatoriosTab> createState() =>
      _ComprasRelatoriosTabState();
}

class _ComprasRelatoriosTabState extends ConsumerState<ComprasRelatoriosTab> {
  int _categoriaTocada = -1;
  String? _mercadoFiltro;

  String? _mercadoDoItem(Map<String, dynamic> item) {
    final listaInfo = item['listas_compras'] as Map<String, dynamic>?;
    final mercado = listaInfo?['mercado']?.toString().trim();
    return (mercado == null || mercado.isEmpty) ? null : mercado;
  }

  Widget _buildFiltroMercado(
    BuildContext context,
    List<Map<String, dynamic>> historicoCompleto,
  ) {
    final mercados =
        historicoCompleto
            .map(_mercadoDoItem)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    if (mercados.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos os mercados'),
                selected: _mercadoFiltro == null,
                onSelected: (_) => setState(() => _mercadoFiltro = null),
              ),
              for (final m in mercados)
                ChoiceChip(
                  label: Text(m),
                  selected: _mercadoFiltro == m,
                  onSelected: (_) => setState(() => _mercadoFiltro = m),
                ),
            ],
          ),
          TextButton.icon(
            onPressed: () => _abrirGerenciarMercados(mercados),
            icon: const Icon(Icons.edit_note, size: 18),
            label: const Text('Gerenciar mercados'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  /// Lista os mercados já cadastrados com ação de renomear/excluir cada um
  /// -- pra corrigir um nome digitado errado ou remover um mercado criado
  /// só de teste, sem precisar editar lista por lista.
  void _abrirGerenciarMercados(List<String> mercadosIniciais) {
    // Declarado fora do StatefulBuilder de propósito: `builder` roda de
    // novo a cada `setSheetState`, então uma variável local dele seria
    // resetada pra `mercadosIniciais` a cada renomeação/exclusão em vez de
    // manter o que já foi feito na folha (mesmo padrão usado em
    // produto_item_sheet.dart).
    var mercados = List<String>.from(mercadosIniciais)..sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> renomear(String nomeAntigo) async {
              final controller = TextEditingController(text: nomeAntigo);
              final nomeNovo = await showDialog<String>(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Renomear mercado'),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(dCtx),
                      style: AppColors.secondaryButtonStyle(context),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: AppColors.primaryButtonStyle(context),
                      onPressed: () =>
                          Navigator.pop(dCtx, controller.text.trim()),
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              );
              if (nomeNovo == null ||
                  nomeNovo.isEmpty ||
                  nomeNovo == nomeAntigo) {
                return;
              }
              await ListasComprasRepo.renomearMercado(nomeAntigo, nomeNovo);
              if (_mercadoFiltro == nomeAntigo) {
                setState(() => _mercadoFiltro = nomeNovo);
              }
              ref.invalidate(_historicoComprasProvider);
              ref.invalidate(listasAtivasProvider);
              ref.invalidate(listasConcluidasProvider);
              setSheetState(
                () => mercados = (mercados..remove(nomeAntigo))
                  ..add(nomeNovo)
                  ..sort(),
              );
            }

            Future<void> excluir(String nome) async {
              final quantidade =
                  await ListasComprasRepo.contagemListasPorMercado(nome);
              if (!context.mounted) return;
              final confirmou = await confirmarExclusaoMercado(
                context,
                nomeMercado: nome,
                quantidadeListas: quantidade,
              );
              if (!confirmou) return;
              await ListasComprasRepo.excluirMercado(nome);
              if (_mercadoFiltro == nome) setState(() => _mercadoFiltro = null);
              ref.invalidate(_historicoComprasProvider);
              ref.invalidate(listasAtivasProvider);
              ref.invalidate(listasConcluidasProvider);
              setSheetState(
                () => mercados = List<String>.from(mercados)..remove(nome),
              );
              if (mercados.isEmpty && ctx.mounted) Navigator.pop(ctx);
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gerenciar mercados',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Corrija um nome digitado errado ou remova um mercado -- as compras continuam salvas, só deixam de ter um mercado definido.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: mercados.length,
                        itemBuilder: (context, index) {
                          final nome = mercados[index];
                          return ListTile(
                            leading: const Icon(Icons.storefront_outlined),
                            title: Text(nome),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Renomear',
                                  onPressed: () => renomear(nome),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Excluir',
                                  onPressed: () => excluir(nome),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionCard(BuildContext context, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E2235)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _buildCategoriasCard(
    BuildContext context,
    List<Map<String, dynamic>> historico,
  ) {
    final Map<String, double> porCategoria = {};
    final Map<String, String> emojiPorCategoria = {};
    for (final item in historico) {
      final total = _num(item['preco']) * _num(item['quantidade'], 1.0);
      if (total <= 0) continue;
      final produto = item['produtos_catalogo'] as Map<String, dynamic>?;
      final categoria =
          produto?['categorias_produtos'] as Map<String, dynamic>?;
      final nome = (categoria?['nome'] ?? 'Sem categoria').toString();
      porCategoria[nome] = (porCategoria[nome] ?? 0) + total;
      emojiPorCategoria[nome] = (categoria?['emoji'] ?? '🛒').toString();
    }
    final entries = porCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalGeral = entries.fold<double>(0, (s, e) => s + e.value);

    if (entries.isEmpty) return const SizedBox.shrink();

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < entries.length; i++) {
      final isTouched = i == _categoriaTocada;
      sections.add(
        PieChartSectionData(
          color: _paletaCores[i % _paletaCores.length],
          value: entries[i].value,
          title: '',
          radius: isTouched ? 45 : 35,
          borderSide: isTouched
              ? BorderSide(color: Colors.white.withOpacity(0.9), width: 3)
              : BorderSide.none,
        ),
      );
    }

    final isTocada = _categoriaTocada >= 0 && _categoriaTocada < entries.length;
    final tocada = isTocada ? entries[_categoriaTocada] : null;

    return _sectionCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Categorias mais compradas',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              if (isTocada)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _categoriaTocada = -1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.iconMuted(context),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Limpar',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  'Toque para ver',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          return;
                        }
                        setState(
                          () => _categoriaTocada = pieTouchResponse
                              .touchedSection!
                              .touchedSectionIndex,
                        );
                      },
                    ),
                    sectionsSpace: 2,
                    centerSpaceRadius: 65,
                    sections: sections,
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 400),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: tocada != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${emojiPorCategoria[tocada.key]} ${tocada.key}',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(tocada.value),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${(tocada.value / totalGeral * 100).toStringAsFixed(1)}% do total',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.mutedText(context),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total gasto',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryText(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(totalGeral),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...entries.take(8).toList().asMap().entries.map((e) {
            final i = e.key;
            final entry = e.value;
            final pct = totalGeral > 0 ? entry.value / totalGeral * 100 : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _paletaCores[i % _paletaCores.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${emojiPorCategoria[entry.key]} ${entry.key}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: AppColors.secondaryText(context),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 76,
                    child: Text(
                      CurrencyFormatter.format(entry.value),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProdutosFrequentesCard(
    BuildContext context,
    List<Map<String, dynamic>> historico,
  ) {
    final Map<String, int> contagem = {};
    final Map<String, double> totalPorProduto = {};
    final Map<String, String> emojiPorProduto = {};
    for (final item in historico) {
      final produto = item['produtos_catalogo'] as Map<String, dynamic>?;
      final nome = (produto?['nome'] ?? item['nome'] ?? 'Produto').toString();
      final total = _num(item['preco']) * _num(item['quantidade'], 1.0);
      contagem[nome] = (contagem[nome] ?? 0) + 1;
      totalPorProduto[nome] = (totalPorProduto[nome] ?? 0) + total;
      emojiPorProduto[nome] = (produto?['emoji'] ?? '🛒').toString();
    }
    final ranking = contagem.keys.toList()
      ..sort((a, b) => contagem[b]!.compareTo(contagem[a]!));
    final top = ranking.take(10).toList();

    if (top.isEmpty) return const SizedBox.shrink();

    return _sectionCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Produtos mais frequentes',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Quantas vezes cada produto entrou numa compra',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText(context),
            ),
          ),
          const SizedBox(height: 16),
          ...top.asMap().entries.map((e) {
            final posicao = e.key + 1;
            final nome = e.value;
            final vezes = contagem[nome]!;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '$posicao',
                      style: TextStyle(
                        color: AppColors.mutedText(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    emojiPorProduto[nome] ?? '🛒',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nome,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${vezes}x',
                    style: TextStyle(
                      color: AppColors.secondaryText(context),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 76,
                    child: Text(
                      CurrencyFormatter.format(totalPorProduto[nome] ?? 0),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGastoMensalCard(
    BuildContext context,
    List<Map<String, dynamic>> historico,
  ) {
    final Map<String, double> porMes = {};
    for (final item in historico) {
      final dataStr = item['updated_at']?.toString();
      if (dataStr == null) continue;
      DateTime data;
      try {
        data = DateTime.parse(dataStr);
      } catch (_) {
        continue;
      }
      final chave = '${data.year}-${data.month.toString().padLeft(2, '0')}';
      final total = _num(item['preco']) * _num(item['quantidade'], 1.0);
      porMes[chave] = (porMes[chave] ?? 0) + total;
    }
    final chavesOrdenadas = porMes.keys.toList()..sort();
    final ultimos = chavesOrdenadas.length > 12
        ? chavesOrdenadas.sublist(chavesOrdenadas.length - 12)
        : chavesOrdenadas;

    if (ultimos.isEmpty) return const SizedBox.shrink();

    double maxVal = 0;
    for (final k in ultimos) {
      if (porMes[k]! > maxVal) maxVal = porMes[k]!;
    }
    if (maxVal == 0) maxVal = 1;

    return _sectionCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gasto por mês',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final partes = ultimos[group.x.toInt()].split('-');
                      final mes = _nomesMeses[int.parse(partes[1])];
                      return BarTooltipItem(
                        '$mes/${partes[0]}\n${CurrencyFormatter.format(rod.toY)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= ultimos.length) return const Text('');
                        final partes = ultimos[i].split('-');
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _nomesMeses[int.parse(partes[1])],
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: AppColors.divider(context), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: ultimos.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: porMes[e.value]!,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  );
                }).toList(),
              ),
              swapAnimationDuration: const Duration(milliseconds: 400),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historicoAsync = ref.watch(_historicoComprasProvider);

    return historicoAsync.when(
      data: (historico) {
        if (historico.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 64,
                    color: AppColors.iconMuted(context),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma compra registrada ainda.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assim que a família marcar itens como comprados, os relatórios aparecem aqui.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.secondaryText(context)),
                  ),
                ],
              ),
            ),
          );
        }

        final historicoFiltrado = _mercadoFiltro == null
            ? historico
            : historico
                  .where((i) => _mercadoDoItem(i) == _mercadoFiltro)
                  .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildFiltroMercado(context, historico),
            if (historicoFiltrado.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Nenhuma compra nesse mercado ainda.',
                    style: TextStyle(color: AppColors.secondaryText(context)),
                  ),
                ),
              )
            else ...[
              _buildCategoriasCard(context, historicoFiltrado),
              _buildProdutosFrequentesCard(context, historicoFiltrado),
              _buildGastoMensalCard(context, historicoFiltrado),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
    );
  }
}
