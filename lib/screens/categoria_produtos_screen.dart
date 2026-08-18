import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/catalogo_provider.dart';
import '../providers/listas_compras_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/produto_item_sheet.dart';

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
  ConsumerState<CategoriaProdutosScreen> createState() =>
      _CategoriaProdutosScreenState();
}

class _CategoriaProdutosScreenState
    extends ConsumerState<CategoriaProdutosScreen> {
  Future<void> _toggleProduto(
    Map<String, dynamic> produto,
    bool jaAdicionado,
  ) async {
    if (jaAdicionado) {
      await CatalogoRepo.removerDaLista(
        listaId: widget.listaId,
        produtoId: produto['id'].toString(),
      );
    } else {
      await CatalogoRepo.adicionarNaLista(
        listaId: widget.listaId,
        produto: produto,
      );
    }
    ref.invalidate(listaItensProvider(widget.listaId));
  }

  Future<void> _criarProdutoCustomizado() async {
    final nomeController = TextEditingController();
    String emoji = widget.emojiTitulo.isNotEmpty ? widget.emojiTitulo : '🛒';
    final tagsEscolhidas = <String>{};
    String? categoriaId = widget.categoriaId;

    final categorias = ref.read(categoriasProdutoProvider).value ?? [];

    InputDecoration campo(String label) {
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
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Novo Produto',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nomeController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: campo('Nome do produto'),
                    ),
                    const SizedBox(height: 16),
                    if (categoriaId == null)
                      DropdownButtonFormField<String>(
                        initialValue: categoriaId,
                        isExpanded: true,
                        decoration: campo('Categoria'),
                        items: categorias
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c['id'].toString(),
                                child: Text('${c['emoji']} ${c['nome']}'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setModalState(() => categoriaId = v),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Ícone',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText(context),
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
                                    ? Theme.of(context).colorScheme.primary
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
                    const SizedBox(height: 16),
                    Text(
                      'Tags (opcional)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText(context),
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
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: AppColors.primaryButtonStyle(context),
                      onPressed:
                          (nomeController.text.trim().isEmpty ||
                              categoriaId == null)
                          ? null
                          : () async {
                              final id =
                                  await CatalogoRepo.criarProdutoCustomizado(
                                    nome: nomeController.text.trim(),
                                    categoriaId: categoriaId!,
                                    emoji: emoji,
                                    tags: tagsEscolhidas.toList(),
                                  );
                              await CatalogoRepo.adicionarNaLista(
                                listaId: widget.listaId,
                                produto: {
                                  'id': id,
                                  'nome': nomeController.text.trim(),
                                  'unidade_padrao': 'Unidade',
                                },
                              );
                              ref.invalidate(
                                listaItensProvider(widget.listaId),
                              );
                              if (widget.categoriaId != null)
                                ref.invalidate(
                                  produtosPorCategoriaProvider(
                                    widget.categoriaId!,
                                  ),
                                );
                              if (widget.tag != null)
                                ref.invalidate(
                                  produtosPorTagProvider(widget.tag!),
                                );
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

  /// Toque no ícone do produto (não no badge +/✓): sempre abre a folha de
  /// edição, seja pra criar o item (com preço/medida) ou editar o que já
  /// está na lista.
  Future<void> _abrirEdicao(
    Map<String, dynamic> produto,
    Map<String, dynamic>? itemExistente,
  ) async {
    final salvou = await showProdutoItemSheet(
      context,
      listaId: widget.listaId,
      itemExistente: itemExistente,
      produtoInicial: itemExistente == null ? produto : null,
      editarCatalogo: true,
    );
    if (salvou) {
      ref.invalidate(listaItensProvider(widget.listaId));
      // Ícone/tags podem ter mudado no catálogo -- recarrega essa grade pra
      // não ficar exibindo o dado antigo em cache.
      if (widget.categoriaId != null)
        ref.invalidate(produtosPorCategoriaProvider(widget.categoriaId!));
      if (widget.tag != null)
        ref.invalidate(produtosPorTagProvider(widget.tag!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final produtosAsync = widget.categoriaId != null
        ? ref.watch(produtosPorCategoriaProvider(widget.categoriaId!))
        : ref.watch(produtosPorTagProvider(widget.tag!));
    final itensListaAsync = ref.watch(listaItensProvider(widget.listaId));
    final itensPorProdutoId = <String, Map<String, dynamic>>{
      for (final i in itensListaAsync.value ?? <Map<String, dynamic>>[])
        if (i['produto_id'] != null) i['produto_id'].toString(): i,
    };

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.emojiTitulo, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.titulo, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: produtosAsync.when(
        data: (produtos) {
          if (produtos.isEmpty) {
            return Center(
              child: Text(
                'Nenhum produto aqui ainda.',
                style: TextStyle(color: AppColors.secondaryText(context)),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            itemCount: produtos.length,
            itemBuilder: (context, index) {
              final produto = produtos[index];
              final produtoId = produto['id'].toString();
              final itemExistente = itensPorProdutoId[produtoId];
              final adicionado = itemExistente != null;
              // O check só deve aparecer quando o item foi de fato comprado
              // -- "está na lista mas ainda não comprado" usa um ícone
              // neutro (menos), pra não parecer que salvar já marca como
              // concluído.
              final comprado =
                  adicionado &&
                  (itemExistente['comprado'] == 1 ||
                      itemExistente['comprado'] == true);
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
                                style: const TextStyle(fontSize: 40),
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
                              child: Icon(
                                badgeIcon,
                                size: 18,
                                color: Colors.white,
                              ),
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
