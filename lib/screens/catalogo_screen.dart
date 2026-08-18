import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/catalogo_provider.dart';
import '../providers/listas_compras_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/produto_item_sheet.dart';
import '../widgets/relatorios_compras.dart';
import 'categoria_produtos_screen.dart';

const _tagIcons = {
  'Vegetariano': '🥗',
  'Vegano': '🌱',
  'Keto': '🥚',
  'Sem Glúten': '🌾',
  'Alto teor de proteína': '💪',
  'Congelador': '❄️',
};

class CatalogoScreen extends ConsumerStatefulWidget {
  final String? listaId;
  const CatalogoScreen({super.key, this.listaId});

  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _buscaController = TextEditingController();
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  void _mostrarErroSemLista() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Crie uma Lista de Compras primeiro')),
    );
  }

  Future<void> _toggleProduto(
    Map<String, dynamic> produto,
    bool jaAdicionado,
  ) async {
    final listaId = widget.listaId;
    if (listaId == null) {
      _mostrarErroSemLista();
      return;
    }
    if (jaAdicionado) {
      await CatalogoRepo.removerDaLista(
        listaId: listaId,
        produtoId: produto['id'].toString(),
      );
    } else {
      await CatalogoRepo.adicionarNaLista(listaId: listaId, produto: produto);
    }
    ref.invalidate(listaItensProvider(listaId));
  }

  /// Toque no ícone do produto (não no badge +/✓): sempre abre a folha de
  /// edição, seja pra criar o item (com preço/medida) ou editar o que já
  /// está na lista.
  Future<void> _abrirEdicao(
    Map<String, dynamic> produto,
    Map<String, dynamic>? itemExistente,
  ) async {
    final listaId = widget.listaId;
    if (listaId == null) {
      _mostrarErroSemLista();
      return;
    }
    final salvou = await showProdutoItemSheet(
      context,
      listaId: listaId,
      itemExistente: itemExistente,
      produtoInicial: itemExistente == null ? produto : null,
      editarCatalogo: true,
    );
    if (salvou) {
      ref.invalidate(listaItensProvider(listaId));
      // Ícone/tags podem ter mudado no catálogo -- recarrega as grades que
      // mostram esse produto pra não ficar exibindo o dado antigo em cache.
      ref.invalidate(produtosPopularesProvider);
      if (_busca.trim().isNotEmpty)
        ref.invalidate(buscarProdutosProvider(_busca));
    }
  }

  Widget _produtoCard(
    Map<String, dynamic> produto,
    Map<String, Map<String, dynamic>> itensPorProdutoId,
  ) {
    final produtoId = produto['id'].toString();
    final itemExistente = itensPorProdutoId[produtoId];
    final adicionado = itemExistente != null;
    // O check só deve aparecer quando o item foi de fato comprado -- "está
    // na lista mas ainda não comprado" usa um ícone neutro (menos), pra não
    // parecer que salvar/adicionar já marca como concluído.
    final comprado =
        adicionado &&
        (itemExistente['comprado'] == 1 || itemExistente['comprado'] == true);
    final IconData badgeIcon = comprado
        ? Icons.check
        : (adicionado ? Icons.remove : Icons.add);
    final Color badgeColor = comprado
        ? Colors.green
        : (adicionado
              ? Colors.blueAccent
              : Theme.of(context).colorScheme.primary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1.2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Material(
                color: adicionado
                    ? Colors.blueAccent.withOpacity(0.15)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _abrirEdicao(produto, itemExistente),
                  child: Center(
                    child: Text(
                      produto['emoji'] ?? '🛒',
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _toggleProduto(produto, adicionado),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(badgeIcon, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          produto['nome'].toString(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBuscaResultados() {
    final resultadosAsync = ref.watch(buscarProdutosProvider(_busca));
    final itensPorProdutoId = <String, Map<String, dynamic>>{};
    if (widget.listaId != null) {
      final itensListaAsync = ref.watch(listaItensProvider(widget.listaId!));
      for (final i in itensListaAsync.value ?? <Map<String, dynamic>>[]) {
        if (i['produto_id'] != null) {
          itensPorProdutoId[i['produto_id'].toString()] = i;
        }
      }
    }

    return resultadosAsync.when(
      data: (produtos) {
        if (produtos.isEmpty) {
          return Center(
            child: Text(
              'Nenhum produto encontrado.',
              style: TextStyle(color: AppColors.secondaryText(context)),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemCount: produtos.length,
          itemBuilder: (context, index) =>
              _produtoCard(produtos[index], itensPorProdutoId),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
    );
  }

  Widget _buildPopularTab() {
    final popularesAsync = ref.watch(produtosPopularesProvider);
    final itensPorProdutoId = <String, Map<String, dynamic>>{};
    if (widget.listaId != null) {
      final itensListaAsync = ref.watch(listaItensProvider(widget.listaId!));
      for (final i in itensListaAsync.value ?? <Map<String, dynamic>>[]) {
        if (i['produto_id'] != null) {
          itensPorProdutoId[i['produto_id'].toString()] = i;
        }
      }
    }

    return popularesAsync.when(
      data: (produtos) {
        if (produtos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Assim que sua família comprar alguns itens, os mais frequentes aparecem aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText(context)),
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemCount: produtos.length,
          itemBuilder: (context, index) =>
              _produtoCard(produtos[index], itensPorProdutoId),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
    );
  }

  Widget _buildCatalogoTab() {
    final categoriasAsync = ref.watch(categoriasProdutoProvider);
    return categoriasAsync.when(
      data: (categorias) {
        final Map<String, List<Map<String, dynamic>>> porGrupo = {};
        for (final c in categorias) {
          final grupo = (c['grupo'] ?? 'Outro').toString();
          porGrupo.putIfAbsent(grupo, () => []).add(c);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Filtros rápidos',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _tagIcons.entries.map((e) {
                return ActionChip(
                  avatar: Text(e.value),
                  label: Text(e.key),
                  shape: const StadiumBorder(),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoriaProdutosScreen(
                        listaId: widget.listaId,
                        titulo: e.key,
                        emojiTitulo: e.value,
                        tag: e.key,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            for (final grupo in porGrupo.entries) ...[
              Text(
                grupo.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: grupo.value.length,
                itemBuilder: (context, index) {
                  final categoria = grupo.value[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoriaProdutosScreen(
                          listaId: widget.listaId,
                          titulo: categoria['nome'].toString(),
                          emojiTitulo: (categoria['emoji'] ?? '🛒').toString(),
                          categoriaId: categoria['id'].toString(),
                        ),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            categoria['emoji'] ?? '🛒',
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              categoria['nome'].toString(),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buscando = _busca.trim().isNotEmpty;
    // O TabBar precisa continuar existindo (só trocamos o filho e a altura)
    // quando a busca está ativa -- se `bottom` virar null, o AppBar remonta
    // sua estrutura interna e o campo de busca perde o foco a cada letra
    // digitada (e de novo ao apagar o texto).
    final tabBar = TabBar(
      controller: _tabController,
      tabs: const [
        Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'Popular'),
        Tab(icon: Icon(Icons.grid_view, size: 18), text: 'Catálogo'),
        Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Relatórios'),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: TextField(
            controller: _buscaController,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: 'Buscar produto',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (v) => setState(() => _busca = v),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: buscando ? Size.zero : tabBar.preferredSize,
          child: buscando ? const SizedBox.shrink() : tabBar,
        ),
      ),
      body: _busca.trim().isNotEmpty
          ? _buildBuscaResultados()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPopularTab(),
                _buildCatalogoTab(),
                const ComprasRelatoriosTab(),
              ],
            ),
    );
  }
}
