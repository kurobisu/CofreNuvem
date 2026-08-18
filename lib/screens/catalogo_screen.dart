import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/catalogo_provider.dart';
import '../providers/listas_compras_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/produto_item_sheet.dart';
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
  final String listaId;
  const CatalogoScreen({super.key, required this.listaId});

  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen> with SingleTickerProviderStateMixin {
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

  Future<void> _toggleProduto(Map<String, dynamic> produto, bool jaAdicionado) async {
    if (jaAdicionado) {
      await CatalogoRepo.removerDaLista(listaId: widget.listaId, produtoId: produto['id'].toString());
      ref.invalidate(listaItensProvider(widget.listaId));
    } else {
      final salvou = await showProdutoItemSheet(context, listaId: widget.listaId, produtoInicial: produto);
      if (salvou) ref.invalidate(listaItensProvider(widget.listaId));
    }
  }

  Widget _produtoCard(Map<String, dynamic> produto, Set<String> produtoIdsNaLista) {
    final produtoId = produto['id'].toString();
    final adicionado = produtoIdsNaLista.contains(produtoId);
    return Container(
      decoration: BoxDecoration(
        color: adicionado ? Colors.blueAccent.withOpacity(0.15) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(produto['emoji'] ?? '🛒', style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  produto['nome'].toString(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _toggleProduto(produto, adicionado),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: adicionado ? Colors.blueAccent : Colors.black45, shape: BoxShape.circle),
                child: Icon(adicionado ? Icons.check : Icons.add, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuscaResultados() {
    final resultadosAsync = ref.watch(buscarProdutosProvider(_busca));
    final itensListaAsync = ref.watch(listaItensProvider(widget.listaId));
    final produtoIdsNaLista = (itensListaAsync.value ?? []).map((i) => i['produto_id']?.toString()).whereType<String>().toSet();

    return resultadosAsync.when(
      data: (produtos) {
        if (produtos.isEmpty) {
          return Center(child: Text('Nenhum produto encontrado.', style: TextStyle(color: AppColors.secondaryText(context))));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85),
          itemCount: produtos.length,
          itemBuilder: (context, index) => _produtoCard(produtos[index], produtoIdsNaLista),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
    );
  }

  Widget _buildPopularTab() {
    final popularesAsync = ref.watch(produtosPopularesProvider);
    final itensListaAsync = ref.watch(listaItensProvider(widget.listaId));
    final produtoIdsNaLista = (itensListaAsync.value ?? []).map((i) => i['produto_id']?.toString()).whereType<String>().toSet();

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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85),
          itemCount: produtos.length,
          itemBuilder: (context, index) => _produtoCard(produtos[index], produtoIdsNaLista),
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
            Text('Filtros rápidos', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context), fontWeight: FontWeight.bold)),
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
                      builder: (_) => CategoriaProdutosScreen(listaId: widget.listaId, titulo: e.key, emojiTitulo: e.value, tag: e.key),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            for (final grupo in porGrupo.entries) ...[
              Text(grupo.key.toUpperCase(), style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context), fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.9),
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
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(categoria['emoji'] ?? '🛒', style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              categoria['nome'].toString(),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
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
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24)),
          child: TextField(
            controller: _buscaController,
            decoration: const InputDecoration(
              hintText: 'Incluir novo item',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (v) => setState(() => _busca = v),
          ),
        ),
        bottom: _busca.trim().isEmpty
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'Popular'),
                  Tab(icon: Icon(Icons.grid_view, size: 18), text: 'Catálogo'),
                  Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Relatórios'),
                ],
              )
            : null,
      ),
      body: _busca.trim().isNotEmpty
          ? _buildBuscaResultados()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPopularTab(),
                _buildCatalogoTab(),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart, size: 64, color: AppColors.iconMuted(context)),
                        const SizedBox(height: 16),
                        const Text('Relatórios em breve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          'Gráficos de categorias mais compradas, produtos frequentes e oscilação de gastos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.secondaryText(context)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
