import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/supabase_helper.dart';
import '../providers/catalogo_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/app_colors.dart';

const _unidades = ['Unidade', 'Kg', 'Litro'];

double _parseCurrency(String text) {
  final str = text
      .replaceAll('R\$', '')
      .replaceAll('.', '')
      .replaceAll(',', '.')
      .trim();
  return double.tryParse(str) ?? 0;
}

IconData _iconeUnidade(String unidade) {
  switch (unidade) {
    case 'Kg':
      return Icons.scale;
    case 'Litro':
      return Icons.liquor;
    default:
      return Icons.inventory_2;
  }
}

/// Passo do +/- e exemplo de preenchimento pra cada unidade: 250g/250ml por
/// toque no Kg/Litro, 1 unidade inteira no caso de contagem.
double _passoUnidade(String unidade) => unidade == 'Unidade' ? 1 : 0.25;

String? _hintQuantidade(String unidade) {
  switch (unidade) {
    case 'Kg':
      return 'Ex: 1.83Kg';
    case 'Litro':
      return 'Ex: 1.5L';
    default:
      return null;
  }
}

/// Decoração padrão dos campos desta folha: preenchimento + borda sempre
/// visível (não dá pra confiar só na cor de fundo contrastar com a folha,
/// já que por padrão as duas vêm praticamente iguais no tema escuro).
InputDecoration _campoDecoration(BuildContext context, String label) {
  final borda = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: AppColors.divider(context), width: 1.2),
  );
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Theme.of(context).cardColor,
    border: borda,
    enabledBorder: borda,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 1.8,
      ),
    ),
  );
}

/// Bottom sheet de adicionar/editar um item da lista, com autocomplete
/// contra o catálogo de produtos. Retorna true se salvou algo.
///
/// [produtoInicial] pré-preenche o formulário a partir de um produto do
/// catálogo (ex: veio do botão "+" numa tela de categoria) sem que isso
/// vire uma edição -- o Salvar continua criando um item novo.
///
/// [editarCatalogo] mostra os controles de ícone/tags do produto (usado
/// quando a folha é aberta a partir do Catálogo); na Lista de Compras esses
/// controles ficam escondidos pra manter o fluxo rápido.
Future<bool> showProdutoItemSheet(
  BuildContext context, {
  required String listaId,
  Map<String, dynamic>? itemExistente,
  Map<String, dynamic>? produtoInicial,
  bool editarCatalogo = false,
}) async {
  final supabase = SupabaseHelper.instance.client;

  final nomeInicial = (itemExistente?['nome'] ?? produtoInicial?['nome'] ?? '')
      .toString();
  final buscaController = TextEditingController(text: nomeInicial);
  final marcaController = TextEditingController(
    text: (produtoInicial?['marca'] ?? '').toString(),
  );
  final precoUnitController = TextEditingController();
  final totalController = TextEditingController();
  final qtdeController = TextEditingController(text: '1');

  String unidade =
      (itemExistente?['unidade'] ??
              produtoInicial?['unidade_padrao'] ??
              'Unidade')
          .toString();
  String emoji = (produtoInicial?['emoji'] ?? '🛒').toString();
  String? produtoId = (itemExistente?['produto_id'] ?? produtoInicial?['id'])
      ?.toString();
  String? categoriaEscolhida;
  Set<String> tagsEscolhidas =
      (produtoInicial?['tags'] as List?)?.map((e) => e.toString()).toSet() ??
      {};
  bool mostrarPersonalizacao = false;
  double? precoAnterior;
  List<Map<String, dynamic>> sugestoes = [];
  List<Map<String, dynamic>> categorias = [];
  bool salvou = false;

  final qtdeInicial =
      ((itemExistente?['quantidade'] ?? 1) as num?)?.toDouble() ?? 1.0;
  qtdeController.text = unidade == 'Unidade'
      ? qtdeInicial.round().toString()
      : qtdeInicial.toString();
  final precoInicial =
      ((itemExistente?['preco'] ?? 0) as num?)?.toDouble() ?? 0.0;
  if (precoInicial > 0) {
    precoUnitController.text = CurrencyFormatter.format(precoInicial);
    final totalInicial = precoInicial * qtdeInicial;
    totalController.text = totalInicial > 0
        ? CurrencyFormatter.format(totalInicial)
        : '';
  }

  Future<Map<String, dynamic>?> buscarEmojiEHistorico(String pid) async {
    try {
      final prod = await supabase
          .from(SupabaseHelper.tableProdutosCatalogo)
          .select()
          .eq('id', pid)
          .maybeSingle();
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

  // Se o item já está ligado a um produto do catálogo, busca os dados reais
  // dele (ícone/tags atuais, pra não abrir a folha "resetada" pro carrinho
  // genérico) e o último preço pago em outra lista, pra já nascer preenchido.
  if (produtoId != null) {
    final extra = await buscarEmojiEHistorico(produtoId);
    final prod = extra?['produto'] as Map<String, dynamic>?;
    if (prod != null) {
      emoji = (prod['emoji'] ?? emoji).toString();
      final tagsRaw = prod['tags'];
      if (tagsRaw is List)
        tagsEscolhidas = tagsRaw.map((e) => e.toString()).toSet();
      marcaController.text = (prod['marca'] ?? '').toString();
    }
    final hist = extra?['historico'] as Map<String, dynamic>?;
    if (hist != null) precoAnterior = ((hist['preco'] ?? 0) as num).toDouble();
  }

  // Categorias pra oferecer o seletor quando o nome digitado não bater com
  // nenhum produto do catálogo -- assim dá pra já salvar o produto novo lá.
  try {
    final rawCategorias = await supabase
        .from(SupabaseHelper.tableCategoriasProdutos)
        .select()
        .order('ordem', ascending: true);
    categorias = rawCategorias
        .map((e) => CaseInsensitiveMap(e as Map<String, dynamic>))
        .cast<Map<String, dynamic>>()
        .toList();
  } catch (_) {}

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          void recalcularTotal() {
            final unit = _parseCurrency(precoUnitController.text);
            final qtde =
                double.tryParse(qtdeController.text.replaceAll(',', '.')) ??
                1.0;
            final total = unit * qtde;
            totalController.text = total > 0
                ? CurrencyFormatter.format(total)
                : '';
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
            setModalState(
              () => sugestoes = raw
                  .map((e) => CaseInsensitiveMap(e as Map<String, dynamic>))
                  .cast<Map<String, dynamic>>()
                  .toList(),
            );
          }

          Future<void> selecionar(Map<String, dynamic> produto) async {
            produtoId = produto['id'].toString();
            buscaController.text = produto['nome'].toString();
            emoji = (produto['emoji'] ?? '🛒').toString();
            unidade = (produto['unidade_padrao'] ?? 'Unidade').toString();
            qtdeController.text = unidade == 'Unidade' ? '1' : '1';
            categoriaEscolhida = null;
            final tagsRaw = produto['tags'];
            tagsEscolhidas = tagsRaw is List
                ? tagsRaw.map((e) => e.toString()).toSet()
                : {};
            marcaController.text = (produto['marca'] ?? '').toString();
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
            final atual =
                double.tryParse(qtdeController.text.replaceAll(',', '.')) ??
                1.0;
            var novo = atual + delta;
            if (novo < (unidade == 'Unidade' ? 1 : 0.25))
              novo = unidade == 'Unidade' ? 1 : 0.25;
            qtdeController.text = unidade == 'Unidade'
                ? novo.round().toString()
                : novo.toStringAsFixed(2);
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
                  style: TextStyle(
                    color: diff > 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }
            } else {
              historicoWidget = Text(
                'Último preço: ${CurrencyFormatter.format(precoAnterior!)}',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }
          }

          Future<void> excluirDoCatalogo() async {
            final etapa1 = await showDialog<bool>(
              context: context,
              builder: (dCtx) => AlertDialog(
                title: const Text('Excluir produto do catálogo?'),
                content: Text(
                  '"$nomeAtual" vai deixar de aparecer no Catálogo pra toda a família. Itens que já estão em listas não são afetados.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    onPressed: () => Navigator.pop(dCtx, true),
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            );
            if (etapa1 != true || !context.mounted) return;

            final etapa2 = await showDialog<bool>(
              context: context,
              builder: (dCtx) => AlertDialog(
                title: const Text('Tem certeza?'),
                content: const Text('Essa ação não pode ser desfeita.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(dCtx, true),
                    child: const Text('Excluir Definitivamente'),
                  ),
                ],
              ),
            );
            if (etapa2 == true && produtoId != null) {
              await CatalogoRepo.excluirProduto(produtoId!);
              salvou = true;
              if (ctx.mounted) Navigator.pop(ctx);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: AppColors.secondaryButtonStyle(context),
                        child: const Text('Cancelar'),
                      ),
                      Text(
                        itemExistente == null ? 'Novo Item' : 'Editar Item',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton(
                        style: AppColors.primaryButtonStyle(context),
                        onPressed: nomeAtual.isEmpty
                            ? null
                            : () async {
                                final unit = _parseCurrency(
                                  precoUnitController.text,
                                );
                                final qtde =
                                    double.tryParse(
                                      qtdeController.text.replaceAll(',', '.'),
                                    ) ??
                                    1.0;
                                var produtoIdFinal = produtoId;
                                if (produtoIdFinal == null) {
                                  // Produto novo -- sempre entra no
                                  // catálogo, mesmo sem categoria escolhida
                                  // (cai em "Sem categoria" nesse caso).
                                  final categoriaFinal =
                                      categoriaEscolhida ??
                                      await CatalogoRepo.categoriaSemCategoriaId();
                                  if (categoriaFinal != null) {
                                    produtoIdFinal =
                                        await CatalogoRepo.criarProdutoCustomizado(
                                          nome: nomeAtual,
                                          categoriaId: categoriaFinal,
                                          emoji: emoji,
                                          tags: tagsEscolhidas.toList(),
                                          marca: marcaController.text,
                                        );
                                  }
                                } else if (editarCatalogo) {
                                  await CatalogoRepo.atualizarProduto(
                                    produtoId: produtoIdFinal,
                                    emoji: emoji,
                                    tags: tagsEscolhidas.toList(),
                                    marca: marcaController.text,
                                  );
                                }
                                final db =
                                    await SupabaseHelper.instance.database;
                                final data = {
                                  'nome': nomeAtual,
                                  'produto_id': produtoIdFinal,
                                  'unidade': unidade,
                                  'quantidade': qtde,
                                  'preco': unit > 0 ? unit : null,
                                  'lista_id': listaId,
                                };
                                if (itemExistente == null) {
                                  await db.insert(
                                    SupabaseHelper.tableListaCompras,
                                    data,
                                  );
                                } else {
                                  await db.update(
                                    SupabaseHelper.tableListaCompras,
                                    data,
                                    where: 'id = ?',
                                    whereArgs: [itemExistente['id']],
                                  );
                                }
                                salvou = true;
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.divider(context),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: buscaController,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Nome do produto',
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (v) {
                              produtoId = null;
                              precoAnterior = null;
                              buscar(v);
                            },
                          ),
                        ),
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: editarCatalogo
                              ? () => setModalState(
                                  () => mostrarPersonalizacao =
                                      !mostrarPersonalizacao,
                                )
                              : null,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.black26,
                                radius: 20,
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                              if (editarCatalogo)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).scaffoldBackgroundColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sugestoes.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.divider(context),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: sugestoes.map((s) {
                          final marca = (s['marca'] ?? '').toString().trim();
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.black26,
                              child: Text((s['emoji'] ?? '🛒').toString()),
                            ),
                            title: Text(s['nome'].toString()),
                            subtitle: marca.isEmpty ? null : Text(marca),
                            onTap: () => selecionar(s),
                          );
                        }).toList(),
                      ),
                    ),
                  if (editarCatalogo && mostrarPersonalizacao) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.divider(context),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ícone',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: emojisDisponiveis.map((e) {
                              final selecionado = emoji == e;
                              return InkWell(
                                onTap: () => setModalState(() => emoji = e),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: selecionado
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.primary.withOpacity(0.2)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: selecionado
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : AppColors.divider(context),
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    e,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: marcaController,
                            textCapitalization: TextCapitalization.words,
                            decoration:
                                _campoDecoration(
                                  context,
                                  'Marca (opcional)',
                                ).copyWith(
                                  hintText: 'Ex: Quero, Bonari...',
                                  isDense: true,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tags',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: tagsDisponiveis.map((t) {
                              final selecionado = tagsEscolhidas.contains(t);
                              return FilterChip(
                                label: Text(t),
                                selected: selecionado,
                                onSelected: (v) => setModalState(
                                  () => v
                                      ? tagsEscolhidas.add(t)
                                      : tagsEscolhidas.remove(t),
                                ),
                              );
                            }).toList(),
                          ),
                          if (produtoId != null) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: excluirDoCatalogo,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Excluir produto do catálogo'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (produtoId == null && nomeAtual.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: categoriaEscolhida,
                      isExpanded: true,
                      decoration: _campoDecoration(
                        context,
                        'Categoria (produto novo)',
                      ),
                      hint: const Text('Selecionar categoria'),
                      items: categorias
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c['id'].toString(),
                              child: Text('${c['emoji']} ${c['nome']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setModalState(() => categoriaEscolhida = v),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        'Produto novo -- já vai pro catálogo ao salvar. Escolher uma categoria é opcional (fica em "Sem categoria" se pular).',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText(context),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: precoUnitController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CurrencyInputFormatter(),
                          ],
                          decoration: _campoDecoration(context, 'Preço'),
                          onChanged: (_) => setModalState(recalcularTotal),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: IgnorePointer(
                          child: TextField(
                            controller: totalController,
                            decoration: _campoDecoration(context, 'Total'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (historicoWidget is! SizedBox)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: historicoWidget,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: unidade,
                          decoration: _campoDecoration(
                            context,
                            'Und. de Medida',
                          ),
                          items: _unidades.map((u) {
                            return DropdownMenuItem(
                              value: u,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_iconeUnidade(u), size: 16),
                                  const SizedBox(width: 6),
                                  Text(u),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setModalState(() {
                              unidade = v!;
                              qtdeController.text = unidade == 'Unidade'
                                  ? '1'
                                  : '1.0';
                              recalcularTotal();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: qtdeController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: unidade != 'Unidade',
                          ),
                          inputFormatters: unidade == 'Unidade'
                              ? [FilteringTextInputFormatter.digitsOnly]
                              : null,
                          decoration: _campoDecoration(context, 'Quantidade')
                              .copyWith(
                                prefixIcon: Icon(
                                  _iconeUnidade(unidade),
                                  size: 18,
                                ),
                                hintText: _hintQuantidade(unidade),
                              ),
                          onChanged: (_) => setModalState(recalcularTotal),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Row(
                            children: [
                              _qtdeBtn(
                                context,
                                Icons.remove,
                                () =>
                                    alterarQuantidade(-_passoUnidade(unidade)),
                              ),
                              const SizedBox(width: 6),
                              _qtdeBtn(
                                context,
                                Icons.add,
                                () => alterarQuantidade(_passoUnidade(unidade)),
                              ),
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
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white),
    ),
  );
}
