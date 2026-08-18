import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/catalogo_provider.dart';
import '../providers/listas_compras_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/produto_item_sheet.dart';

const _emojisComuns = [
  '🛒', '🍎', '🥦', '🍞', '🧀', '🥩', '🐟', '🥫', '🥤', '☕', '🍷', '🧴', '🧸', '💊', '👕', '💐', '🧽', '📝', '🦴', '🍕', '🍪', '🥛', '🥚', '🍚',
];

class CategoriaProdutosScreen extends ConsumerStatefulWidget {
  final String listaId;
  final String titulo;
  final String emojiTitulo;
  final String? categoriaId;
  final String? tag;

  const CategoriaProdutosScreen({
    super.key,
    required this.listaId,
    required this.titulo,
    required this.emojiTitulo,
    this.categoriaId,
    this.tag,
  });

  @override
  ConsumerState<CategoriaProdutosScreen> createState() => _CategoriaProdutosScreenState();
}

class _CategoriaProdutosScreenState extends ConsumerState<CategoriaProdutosScreen> {
  Future<void> _toggleProduto(Map<String, dynamic> produto, bool jaAdicionado) async {
    if (jaAdicionado) {
      await CatalogoRepo.removerDaLista(listaId: widget.listaId, produtoId: produto['id'].toString());
      ref.invalidate(listaItensProvider(widget.listaId));
    } else {
      final salvou = await showProdutoItemSheet(context, listaId: widget.listaId, produtoInicial: produto);
      if (salvou) ref.invalidate(listaItensProvider(widget.listaId));
    }
  }

  Future<void> _criarProdutoCustomizado() async {
    final nomeController = TextEditingController();
    String emoji = widget.emojiTitulo.isNotEmpty ? widget.emojiTitulo : '🛒';
    final tagsEscolhidas = <String>{};
    String? categoriaId = widget.categoriaId;

    final categorias = ref.read(categoriasProdutoProvider).value ?? [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Novo Produto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nomeController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Nome do produto', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    if (categoriaId == null)
                      DropdownButtonFormField<String>(
                        initialValue: categoriaId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                        items: categorias
                            .map((c) => DropdownMenuItem<String>(value: c['id'].toString(), child: Text('${c['emoji']} ${c['nome']}')))
                            .toList(),
                        onChanged: (v) => setModalState(() => categoriaId = v),
                      ),
                    const SizedBox(height: 16),
                    Text('Ícone', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _emojisComuns.map((e) {
                        final selecionado = emoji == e;
                        return InkWell(
                          onTap: () => setModalState(() => emoji = e),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selecionado ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Colors.transparent,
                              border: Border.all(color: selecionado ? Theme.of(context).colorScheme.primary : AppColors.divider(context)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 20)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('Tags (opcional)', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tagsDisponiveis.map((t) {
                        final selecionado = tagsEscolhidas.contains(t);
                        return FilterChip(
                          label: Text(t),
                          selected: selecionado,
                          onSelected: (v) => setModalState(() => v ? tagsEscolhidas.add(t) : tagsEscolhidas.remove(t)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      onPressed: (nomeController.text.trim().isEmpty || categoriaId == null)
                          ? null
                          : () async {
                              final id = await CatalogoRepo.criarProdutoCustomizado(
                                nome: nomeController.text.trim(),
                                categoriaId: categoriaId!,
                                emoji: emoji,
                                tags: tagsEscolhidas.toList(),
                              );
                              await CatalogoRepo.adicionarNaLista(
                                listaId: widget.listaId,
                                produto: {'id': id, 'nome': nomeController.text.trim(), 'unidade_padrao': 'Unidade'},
                              );
                              ref.invalidate(listaItensProvider(widget.listaId));
                              if (widget.categoriaId != null) ref.invalidate(produtosPorCategoriaProvider(widget.categoriaId!));
                              if (widget.tag != null) ref.invalidate(produtosPorTagProvider(widget.tag!));
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      child: const Text('Criar e Adicionar'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final produtosAsync = widget.categoriaId != null
        ? ref.watch(produtosPorCategoriaProvider(widget.categoriaId!))
        : ref.watch(produtosPorTagProvider(widget.tag!));
    final itensListaAsync = ref.watch(listaItensProvider(widget.listaId));
    final produtoIdsNaLista = (itensListaAsync.value ?? [])
        .map((i) => i['produto_id']?.toString())
        .whereType<String>()
        .toSet();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.emojiTitulo, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.titulo, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: produtosAsync.when(
        data: (produtos) {
          if (produtos.isEmpty) {
            return Center(
              child: Text('Nenhum produto aqui ainda.', style: TextStyle(color: AppColors.secondaryText(context))),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85),
            itemCount: produtos.length,
            itemBuilder: (context, index) {
              final produto = produtos[index];
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
                        Text(produto['emoji'] ?? '🛒', style: const TextStyle(fontSize: 40)),
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
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: adicionado ? Colors.blueAccent : Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(adicionado ? Icons.check : Icons.add, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _criarProdutoCustomizado,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
    );
  }
}
