import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';
import '../providers/listas_compras_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/app_colors.dart';
import '../widgets/produto_item_sheet.dart';
import 'catalogo_screen.dart';
import 'transaction_form_screen.dart';

class ListaDetalheScreen extends ConsumerStatefulWidget {
  final String listaId;
  final String nomeInicial;

  const ListaDetalheScreen({super.key, required this.listaId, required this.nomeInicial});

  @override
  ConsumerState<ListaDetalheScreen> createState() => _ListaDetalheScreenState();
}

class _ListaDetalheScreenState extends ConsumerState<ListaDetalheScreen> {
  late String _nomeLista;
  String _ordenacao = 'Personalizada';
  bool _ocultarMarcados = false;

  @override
  void initState() {
    super.initState();
    _nomeLista = widget.nomeInicial;
  }

  double _num(dynamic v, [double fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  bool _isMarcado(Map<String, dynamic> item) => item['comprado'] == 1 || item['comprado'] == true;

  void _refresh() => ref.invalidate(listaItensProvider(widget.listaId));

  Future<void> _abrirItemSheet([Map<String, dynamic>? item]) async {
    final salvou = await showProdutoItemSheet(context, listaId: widget.listaId, itemExistente: item);
    if (salvou) _refresh();
  }

  Future<void> _toggleItem(Map<String, dynamic> item) async {
    final db = await SupabaseHelper.instance.database;
    await db.update(SupabaseHelper.tableListaCompras, {'comprado': _isMarcado(item) ? 0 : 1}, where: 'id = ?', whereArgs: [item['id']]);
    _refresh();
  }

  Future<void> _renomearLista() async {
    final controller = TextEditingController(text: _nomeLista);
    final novoNome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renomear Lista'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome da lista', border: OutlineInputBorder()),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: AppColors.secondaryButtonStyle(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: AppColors.primaryButtonStyle(context),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (novoNome != null && novoNome.isNotEmpty) {
      await ListasComprasRepo.renomear(widget.listaId, novoNome);
      if (mounted) setState(() => _nomeLista = novoNome);
    }
  }

  Future<void> _excluirLista() async {
    final etapa1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "$_nomeLista"?'),
        content: const Text('Todos os itens dessa lista serão excluídos junto.'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: AppColors.secondaryButtonStyle(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuar')),
        ],
      ),
    );
    if (etapa1 != true || !mounted) return;

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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir Definitivamente'),
          ),
        ],
      ),
    );
    if (etapa2 == true) {
      await ListasComprasRepo.excluir(widget.listaId);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _finalizarCompra(List<Map<String, dynamic>> itens) async {
    final comprados = itens.where(_isMarcado).toList();
    if (comprados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marque pelo menos um item como comprado.')));
      return;
    }

    double total = 0;
    final ids = <String>[];
    for (final item in comprados) {
      total += _num(item['preco']) * _num(item['quantidade'], 1.0);
      ids.add(item['id'].toString());
    }

    final db = await SupabaseHelper.instance.database;
    final catList = await db.query(SupabaseHelper.tableCategorias, where: "Nome = 'Mercado'");
    String? categoriaId;
    if (catList.isEmpty) {
      categoriaId = await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Mercado', 'Cor_Hexadecimal': '#4CAF50', 'Tipo': 'Ambas'});
    } else {
      categoriaId = catList.first['ID'].toString();
    }

    if (!mounted) return;
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionFormScreen(
          initialDescricao: 'Compras - $_nomeLista',
          initialValor: total,
          initialCategoria: categoriaId,
          shoppingListItemIds: ids,
          forceDespesa: true,
        ),
      ),
    );

    // Só conclui a lista se a transação foi realmente salva -- se o usuário
    // saiu da tela sem salvar, a lista deve continuar ativa do jeito que
    // estava.
    if (salvou == true) {
      await ListasComprasRepo.concluirLista(widget.listaId);
      if (mounted) Navigator.pop(context);
    }
  }

  void _showOrdenarMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opcao in ['Personalizada', 'Categoria', 'Alfabética'])
              RadioListTile<String>(
                value: opcao,
                groupValue: _ordenacao,
                title: Text(opcao),
                onChanged: (v) {
                  setState(() => _ordenacao = v!);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showKebabMenu(List<Map<String, dynamic>> itens) {
    final algumMarcado = itens.any(_isMarcado);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renomear lista'),
              onTap: () {
                Navigator.pop(ctx);
                _renomearLista();
              },
            ),
            ListTile(
              leading: const Icon(Icons.sort),
              title: const Text('Ordenar itens'),
              onTap: () {
                Navigator.pop(ctx);
                _showOrdenarMenu();
              },
            ),
            ListTile(
              leading: Icon(algumMarcado ? Icons.check_box_outline_blank : Icons.check_box),
              title: Text(algumMarcado ? 'Desmarcar todos' : 'Marcar todos'),
              onTap: () async {
                Navigator.pop(ctx);
                await ListasComprasRepo.marcarTodos(widget.listaId, !algumMarcado);
                _refresh();
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_checkout, color: Colors.green),
              title: const Text('Finalizar compra'),
              onTap: () {
                Navigator.pop(ctx);
                _finalizarCompra(itens);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Excluir lista', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _excluirLista();
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _ordenarItens(List<Map<String, dynamic>> itens) {
    final list = List<Map<String, dynamic>>.from(itens);
    if (_ordenacao == 'Alfabética') {
      list.sort((a, b) => (a['nome'] ?? '').toString().toLowerCase().compareTo((b['nome'] ?? '').toString().toLowerCase()));
    } else if (_ordenacao == 'Categoria') {
      list.sort((a, b) {
        final catA = (a['produtos_catalogo']?['categorias_produtos']?['nome'] ?? 'zzz').toString();
        final catB = (b['produtos_catalogo']?['categorias_produtos']?['nome'] ?? 'zzz').toString();
        final cmp = catA.compareTo(catB);
        if (cmp != 0) return cmp;
        return (a['nome'] ?? '').toString().toLowerCase().compareTo((b['nome'] ?? '').toString().toLowerCase());
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final itensAsync = ref.watch(listaItensProvider(widget.listaId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_nomeLista, overflow: TextOverflow.ellipsis),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogoScreen(listaId: widget.listaId)));
                _refresh();
              },
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
                foregroundColor: Theme.of(context).colorScheme.primary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: const Icon(Icons.grid_view, size: 18),
              label: const Text('Catálogo', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          itensAsync.maybeWhen(
            data: (itens) => IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showKebabMenu(itens)),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: itensAsync.when(
              data: (itensRaw) {
                if (itensRaw.isEmpty) return _buildEmptyState();

                final itens = _ordenarItens(itensRaw);
                final naoMarcados = itens.where((i) => !_isMarcado(i)).toList();
                final marcados = itens.where(_isMarcado).toList();

                double totalNaoMarcados = 0, totalMarcados = 0;
                for (final i in naoMarcados) {
                  totalNaoMarcados += _num(i['preco']) * _num(i['quantidade'], 1.0);
                }
                for (final i in marcados) {
                  totalMarcados += _num(i['preco']) * _num(i['quantidade'], 1.0);
                }

                final produtoIds = itens.map((i) => i['produto_id']?.toString()).whereType<String>().toSet().toList();
                final precosAsync = ref.watch(precosAnterioresProvider((produtoIds: produtoIds, excetoListaId: widget.listaId)));
                final precosAnteriores = precosAsync.value ?? <String, double>{};

                return ListView(
                  children: [
                    ...naoMarcados.map((item) => _buildItemTile(item, precosAnteriores)),
                    _buildResumoBar(totalNaoMarcados, totalMarcados),
                    if (marcados.isNotEmpty) ...[
                      InkWell(
                        onTap: () => setState(() => _ocultarMarcados = !_ocultarMarcados),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '(${marcados.length}) ${_ocultarMarcados ? 'Mostrar' : 'Ocultar'} itens marcados',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Icon(_ocultarMarcados ? Icons.expand_more : Icons.expand_less),
                            ],
                          ),
                        ),
                      ),
                      if (!_ocultarMarcados) ...marcados.map((item) => _buildItemTile(item, precosAnteriores, marcado: true)),
                    ],
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Erro: $err')),
            ),
          ),
          _buildBottomInputPanel(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined, size: 96, color: Colors.green.withOpacity(0.6)),
            const SizedBox(height: 24),
            const Text('O que você precisa comprar?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Toque no botão "+" para começar a incluir produtos',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item, Map<String, double> precosAnteriores, {bool marcado = false}) {
    final nome = (item['nome'] ?? '').toString();
    final preco = _num(item['preco']);
    final qtde = _num(item['quantidade'], 1.0);
    final unidade = (item['unidade'] ?? 'Unidade').toString();
    final total = preco * qtde;
    final produtoId = item['produto_id']?.toString();

    Widget? oscilacao;
    if (produtoId != null && precosAnteriores.containsKey(produtoId) && preco > 0) {
      final anterior = precosAnteriores[produtoId]!;
      if (preco > anterior) {
        oscilacao = const Icon(Icons.arrow_upward, color: Colors.red, size: 14);
      } else if (preco < anterior) {
        oscilacao = const Icon(Icons.arrow_downward, color: Colors.green, size: 14);
      } else {
        oscilacao = Icon(Icons.remove, color: Colors.blue.shade300, size: 14);
      }
    }

    String? qtdeLabel;
    if (unidade == 'Unidade') {
      if (qtde != 1) qtdeLabel = qtde.round().toString();
    } else {
      final qtdeStr = qtde % 1 == 0 ? qtde.toStringAsFixed(0) : qtde.toString();
      qtdeLabel = '$qtdeStr $unidade';
    }

    return ListTile(
      leading: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _toggleItem(item),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: marcado ? Colors.green : Colors.transparent,
            border: Border.all(color: marcado ? Colors.green : Colors.blueAccent, width: 2),
          ),
          child: marcado ? const Icon(Icons.check, size: 18, color: Colors.black) : null,
        ),
      ),
      title: Text(
        nome,
        style: TextStyle(color: marcado ? Colors.white38 : Colors.white, decoration: marcado ? TextDecoration.lineThrough : null),
      ),
      onTap: () => _abrirItemSheet(item),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (qtdeLabel != null) Padding(padding: const EdgeInsets.only(right: 8), child: Text(qtdeLabel, style: TextStyle(color: AppColors.secondaryText(context)))),
          if (oscilacao != null) Padding(padding: const EdgeInsets.only(right: 4), child: oscilacao),
          Text(total > 0 ? CurrencyFormatter.format(total) : '-', style: TextStyle(color: marcado ? Colors.white38 : Colors.white)),
        ],
      ),
    );
  }

  Widget _buildResumoBar(double naoMarcados, double marcados) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _resumoColuna('Não marcados', naoMarcados),
          _resumoColuna('Marcados', marcados),
          _resumoColuna('Total', naoMarcados + marcados),
        ],
      ),
    );
  }

  Widget _resumoColuna(String label, double valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.secondaryText(context), fontSize: 12)),
        Text(CurrencyFormatter.format(valor), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildBottomInputPanel() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: Color(0xFF1E2A3A), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _abrirItemSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                child: const Text('Eu preciso de ...', style: TextStyle(color: Colors.black54)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _abrirItemSheet(),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
