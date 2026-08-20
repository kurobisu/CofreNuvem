import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';
import '../providers/listas_compras_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/app_colors.dart';
import '../utils/tutorial_keys.dart';
import '../utils/tutorial_content.dart';
import '../widgets/lista_concluida_delete_dialog.dart';
import '../widgets/produto_item_sheet.dart';
import '../widgets/tutorial_button.dart';
import 'catalogo_screen.dart';
import 'transaction_form_screen.dart';

class ListaDetalheScreen extends ConsumerStatefulWidget {
  final String listaId;
  final String nomeInicial;

  const ListaDetalheScreen({
    super.key,
    required this.listaId,
    required this.nomeInicial,
  });

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

  bool _isMarcado(Map<String, dynamic> item) =>
      item['comprado'] == 1 || item['comprado'] == true;

  /// Lista já concluída (finalizada anteriormente) -- ainda pode ser
  /// editada, mas cada edição precisa manter a Transação vinculada em dia.
  bool get _concluida =>
      ref.read(listaInfoProvider(widget.listaId)).value?['status']
          ?.toString() ==
      'Concluida';

  void _refresh() => ref.invalidate(listaItensProvider(widget.listaId));

  Future<void> _sincronizarSeConcluida() async {
    if (_concluida) {
      await ListasComprasRepo.sincronizarTransacaoDaLista(widget.listaId);
    }
  }

  Future<void> _abrirItemSheet([Map<String, dynamic>? item]) async {
    final salvou = await showProdutoItemSheet(
      context,
      listaId: widget.listaId,
      itemExistente: item,
    );
    if (salvou) {
      _refresh();
      await _sincronizarSeConcluida();
    }
  }

  Future<void> _toggleItem(Map<String, dynamic> item) async {
    final db = await SupabaseHelper.instance.database;
    await db.update(
      SupabaseHelper.tableListaCompras,
      {'comprado': _isMarcado(item) ? 0 : 1},
      where: 'id = ?',
      whereArgs: [item['id']],
    );
    _refresh();
    await _sincronizarSeConcluida();
  }

  Future<bool> _confirmarRemocao(String nome) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remover Item?'),
            content: Text('Deseja remover "$nome" da sua lista de compras?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _removerItem(Map<String, dynamic> item) async {
    await ListasComprasRepo.removerItem(item['id'].toString());
    _refresh();
    await _sincronizarSeConcluida();
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item "${item['nome']}" removido'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
          decoration: const InputDecoration(
            labelText: 'Nome da lista',
            border: OutlineInputBorder(),
          ),
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

  Future<void> _definirMercado(String? mercadoAtual) async {
    // Busca os mercados já usados pela família antes de abrir o diálogo, pra
    // alimentar o autocomplete -- sem isso, cada grafia diferente do mesmo
    // mercado (ex: "Atacadão" vs "atacadao") vira uma entrada solta nos
    // Relatórios em vez de somar no mesmo filtro.
    final conhecidos = await ListasComprasRepo.mercadosConhecidos();
    if (!mounted) return;

    String mercadoDigitado = mercadoAtual ?? '';
    final novoMercado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mercado desta lista'),
        content: Autocomplete<String>(
          initialValue: TextEditingValue(text: mercadoAtual ?? ''),
          optionsBuilder: (TextEditingValue value) {
            final busca = value.text.trim().toLowerCase();
            if (busca.isEmpty) return conhecidos;
            return conhecidos.where((m) => m.toLowerCase().contains(busca));
          },
          onSelected: (selection) => mercadoDigitado = selection,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Busque ou digite um mercado novo',
                hintText: 'Ex: Atacadão, Carrefour...',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => mercadoDigitado = v,
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: AppColors.secondaryButtonStyle(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: AppColors.primaryButtonStyle(context),
            onPressed: () => Navigator.pop(ctx, mercadoDigitado.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (novoMercado != null) {
      await ListasComprasRepo.definirMercado(widget.listaId, novoMercado);
      ref.invalidate(listaInfoProvider(widget.listaId));
    }
  }

  Future<void> _excluirLista() async {
    if (_concluida) {
      final valorTransacao = await ListasComprasRepo.valorTransacaoVinculada(
        widget.listaId,
      );
      if (!mounted) return;
      final confirmou = await confirmarExclusaoListaConcluida(
        context,
        nomeLista: _nomeLista,
        valorTransacao: valorTransacao,
      );
      if (confirmou && mounted) {
        await ListasComprasRepo.excluirConcluida(
          widget.listaId,
          excluirTransacaoVinculada: valorTransacao != null,
        );
        if (mounted) Navigator.pop(context);
      }
      return;
    }

    final etapa1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "$_nomeLista"?'),
        content: const Text(
          'Todos os itens dessa lista serão excluídos junto.',
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
    if (etapa2 == true) {
      await ListasComprasRepo.excluir(widget.listaId);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _finalizarCompra(List<Map<String, dynamic>> itens) async {
    final comprados = itens.where(_isMarcado).toList();
    if (comprados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marque pelo menos um item como comprado.'),
        ),
      );
      return;
    }

    double total = 0;
    final ids = <String>[];
    for (final item in comprados) {
      total += _num(item['preco']) * _num(item['quantidade'], 1.0);
      ids.add(item['id'].toString());
    }

    // OnlineProxy.query só filtra por uma coluna por vez, e "Mercado" pode
    // coexistir com subcategorias de mesmo nome em outras árvores -- usa o
    // client direto pra achar exatamente a categoria-pai raiz "Mercado"
    // (mesmo critério usado em manage_categories_screen.dart pra montar a
    // aba dedicada de Mercado: Nome == 'Mercado' e Parent_ID nulo).
    final client = SupabaseHelper.instance.client;
    String? categoriaId;
    try {
      // Ordena por 'ordem' igual a query que TransactionFormScreen usa pra
      // carregar todas as categorias -- se existir mais de uma categoria
      // "Mercado" raiz duplicada, isso garante que pegamos a mesma que a
      // deduplicação por nome de _updateCategoriasAtivas vai manter (a
      // primeira em Ordem), senão o category ficaria selecionado mas
      // "inválido" pro dropdown e cairia num fallback errado.
      final mercado = await client
          .from(SupabaseHelper.tableCategorias)
          .select('id')
          .eq('nome', 'Mercado')
          .filter('parent_id', 'is', null)
          .filter('deleted_at', 'is', null)
          .order('ordem', ascending: true)
          .limit(1)
          .maybeSingle();
      categoriaId = mercado?['id']?.toString();
    } catch (_) {}
    if (categoriaId == null) {
      final novaCategoria = await client
          .from(SupabaseHelper.tableCategorias)
          .insert({
            'auth_id': client.auth.currentUser?.id,
            'nome': 'Mercado',
            'cor_hexadecimal': '#4CAF50',
            'tipo': 'Ambas',
          })
          .select('id')
          .single();
      categoriaId = novaCategoria['id'].toString();
    }

    if (!mounted) return;
    final transacaoId = await Navigator.push<String>(
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
    if (transacaoId != null) {
      await ListasComprasRepo.concluirLista(
        widget.listaId,
        transacaoId: transacaoId,
      );
      ref.invalidate(listasConcluidasProvider);
      ref.invalidate(listaInfoProvider(widget.listaId));
      if (mounted) Navigator.pop(context);
    }
  }

  void _showOrdenarMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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

  void _showKebabMenu(List<Map<String, dynamic>> itens, String? mercadoAtual) {
    final algumMarcado = itens.any(_isMarcado);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Definir mercado'),
              onTap: () {
                Navigator.pop(ctx);
                _definirMercado(mercadoAtual);
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
              leading: Icon(
                algumMarcado ? Icons.check_box_outline_blank : Icons.check_box,
              ),
              title: Text(algumMarcado ? 'Desmarcar todos' : 'Marcar todos'),
              onTap: () async {
                Navigator.pop(ctx);
                await ListasComprasRepo.marcarTodos(
                  widget.listaId,
                  !algumMarcado,
                );
                _refresh();
                await _sincronizarSeConcluida();
              },
            ),
            if (!_concluida)
              ListTile(
                leading: const Icon(
                  Icons.shopping_cart_checkout,
                  color: Colors.green,
                ),
                title: const Text('Finalizar compra'),
                onTap: () {
                  Navigator.pop(ctx);
                  _finalizarCompra(itens);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Excluir lista',
                style: TextStyle(color: Colors.red),
              ),
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
      list.sort(
        (a, b) => (a['nome'] ?? '').toString().toLowerCase().compareTo(
          (b['nome'] ?? '').toString().toLowerCase(),
        ),
      );
    } else if (_ordenacao == 'Categoria') {
      list.sort((a, b) {
        final catA =
            (a['produtos_catalogo']?['categorias_produtos']?['nome'] ?? 'zzz')
                .toString();
        final catB =
            (b['produtos_catalogo']?['categorias_produtos']?['nome'] ?? 'zzz')
                .toString();
        final cmp = catA.compareTo(catB);
        if (cmp != 0) return cmp;
        return (a['nome'] ?? '').toString().toLowerCase().compareTo(
          (b['nome'] ?? '').toString().toLowerCase(),
        );
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final itensAsync = ref.watch(listaItensProvider(widget.listaId));
    final info = ref.watch(listaInfoProvider(widget.listaId)).value;
    final mercado = info?['mercado']?.toString().trim();
    final mercadoValido = (mercado == null || mercado.isEmpty) ? null : mercado;
    final concluida = info?['status']?.toString() == 'Concluida';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(_nomeLista, overflow: TextOverflow.ellipsis),
                ),
                if (concluida)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Concluída',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
              ],
            ),
            if (mercadoValido != null)
              Text(
                '🏬 $mercadoValido',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: AppColors.secondaryText(context),
                ),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CatalogoScreen(listaId: widget.listaId),
                  ),
                );
                _refresh();
              },
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.16),
                foregroundColor: Theme.of(context).colorScheme.primary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.grid_view, size: 18),
              label: const Text(
                'Catálogo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          itensAsync.maybeWhen(
            data: (itens) => IconButton(
              key: TutorialKeys.listaDetalheMenuButton,
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showKebabMenu(itens, mercadoValido),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const TutorialButton(screen: TutorialScreens.listaDetalhe),
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
                  totalNaoMarcados +=
                      _num(i['preco']) * _num(i['quantidade'], 1.0);
                }
                for (final i in marcados) {
                  totalMarcados +=
                      _num(i['preco']) * _num(i['quantidade'], 1.0);
                }

                final pares = itens
                    .map((i) {
                      final produtoId = i['produto_id']?.toString();
                      if (produtoId == null) return null;
                      return chaveProdutoMarca(
                        produtoId,
                        i['marca_id']?.toString(),
                      );
                    })
                    .whereType<String>()
                    .toSet()
                    .toList();
                final precosAsync = ref.watch(
                  precosAnterioresProvider((
                    pares: pares,
                    excetoListaId: widget.listaId,
                  )),
                );
                final precosAnteriores =
                    precosAsync.value ?? <String, double>{};

                return ListView(
                  children: [
                    ...naoMarcados.map(
                      (item) => _buildItemTile(item, precosAnteriores),
                    ),
                    _buildResumoBar(totalNaoMarcados, totalMarcados),
                    if (marcados.isNotEmpty) ...[
                      InkWell(
                        onTap: () => setState(
                          () => _ocultarMarcados = !_ocultarMarcados,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '(${marcados.length}) ${_ocultarMarcados ? 'Mostrar' : 'Ocultar'} itens marcados',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(
                                _ocultarMarcados
                                    ? Icons.expand_more
                                    : Icons.expand_less,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!_ocultarMarcados)
                        ...marcados.map(
                          (item) => _buildItemTile(
                            item,
                            precosAnteriores,
                            marcado: true,
                          ),
                        ),
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
            Icon(
              Icons.shopping_basket_outlined,
              size: 96,
              color: Colors.green.withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            const Text(
              'O que você precisa comprar?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
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

  Widget _buildItemTile(
    Map<String, dynamic> item,
    Map<String, double> precosAnteriores, {
    bool marcado = false,
  }) {
    final nome = (item['nome'] ?? '').toString();
    final preco = _num(item['preco']);
    final qtde = _num(item['quantidade'], 1.0);
    final unidade = (item['unidade'] ?? 'Unidade').toString();
    final total = preco * qtde;
    final produtoId = item['produto_id']?.toString();
    final categoriaEmoji =
        (item['produtos_catalogo']?['categorias_produtos']?['emoji'] ?? '🛒')
            .toString();

    Widget? oscilacao;
    final chavePreco = produtoId == null
        ? null
        : chaveProdutoMarca(produtoId, item['marca_id']?.toString());
    if (chavePreco != null &&
        precosAnteriores.containsKey(chavePreco) &&
        preco > 0) {
      final anterior = precosAnteriores[chavePreco]!;
      if (preco > anterior) {
        oscilacao = const Icon(Icons.arrow_upward, color: Colors.red, size: 14);
      } else if (preco < anterior) {
        oscilacao = const Icon(
          Icons.arrow_downward,
          color: Colors.green,
          size: 14,
        );
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

    return Dismissible(
      key: ValueKey(item['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Excluir',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (_) => _confirmarRemocao(nome),
      onDismissed: (_) => _removerItem(item),
      child: ListTile(
        leading: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _toggleItem(item),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: marcado ? Colors.green : Colors.transparent,
              border: Border.all(
                color: marcado ? Colors.green : Colors.blueAccent,
                width: 2,
              ),
            ),
            child: marcado
                ? const Icon(Icons.check, size: 18, color: Colors.black)
                : Center(
                    child: Text(
                      categoriaEmoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
          ),
        ),
        title: Text(
          nome,
          style: TextStyle(
            color: marcado ? Colors.white38 : Colors.white,
            decoration: marcado ? TextDecoration.lineThrough : null,
          ),
        ),
        onTap: () => _abrirItemSheet(item),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (qtdeLabel != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  qtdeLabel,
                  style: TextStyle(color: AppColors.secondaryText(context)),
                ),
              ),
            if (oscilacao != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: oscilacao,
              ),
            Text(
              total > 0 ? CurrencyFormatter.format(total) : '-',
              style: TextStyle(color: marcado ? Colors.white38 : Colors.white),
            ),
          ],
        ),
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
        Text(
          label,
          style: TextStyle(
            color: AppColors.secondaryText(context),
            fontSize: 12,
          ),
        ),
        Text(
          CurrencyFormatter.format(valor),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomInputPanel() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2A3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _abrirItemSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Text(
                  'Eu preciso de ...',
                  style: TextStyle(color: Colors.black54),
                ),
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
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
