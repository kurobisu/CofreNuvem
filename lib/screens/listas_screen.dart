import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/listas_compras_provider.dart';
import '../utils/app_colors.dart';
import '../utils/tutorial_keys.dart';
import '../widgets/nova_lista_sheet.dart';
import 'historico_listas_screen.dart';
import 'lista_detalhe_screen.dart';

class ListasScreen extends ConsumerWidget {
  const ListasScreen({super.key});

  Future<void> _abrirLista(BuildContext context, WidgetRef ref, String id, String nome) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ListaDetalheScreen(listaId: id, nomeInicial: nome)));
    ref.invalidate(listasAtivasProvider);
  }

  Future<void> _criarLista(BuildContext context, WidgetRef ref) async {
    final id = await showNovaListaSheet(context);
    ref.invalidate(listasAtivasProvider);
    if (id != null && context.mounted) {
      await _abrirLista(context, ref, id, '');
    }
  }

  Future<void> _renomear(BuildContext context, WidgetRef ref, ListaCompras lista) async {
    final controller = TextEditingController(text: lista.nome);
    final novoNome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renomear Lista'),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Salvar')),
        ],
      ),
    );
    if (novoNome != null && novoNome.isNotEmpty) {
      await ListasComprasRepo.renomear(lista.id, novoNome);
      ref.invalidate(listasAtivasProvider);
    }
  }

  Future<void> _duplicar(BuildContext context, WidgetRef ref, ListaCompras lista) async {
    await ListasComprasRepo.duplicar(lista.id, '${lista.nome} (cópia)');
    ref.invalidate(listasAtivasProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lista duplicada!')));
    }
  }

  Future<void> _excluir(BuildContext context, WidgetRef ref, ListaCompras lista) async {
    final etapa1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "${lista.nome}"?'),
        content: const Text('Todos os itens dessa lista serão excluídos junto.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (etapa1 != true) return;
    if (!context.mounted) return;

    final etapa2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tem certeza?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir Definitivamente'),
          ),
        ],
      ),
    );
    if (etapa2 == true) {
      await ListasComprasRepo.excluir(lista.id);
      ref.invalidate(listasAtivasProvider);
    }
  }

  void _showCardMenu(BuildContext context, WidgetRef ref, ListaCompras lista) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renomear a lista'),
              onTap: () {
                Navigator.pop(ctx);
                _renomear(context, ref, lista);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Criar uma cópia'),
              onTap: () {
                Navigator.pop(ctx);
                _duplicar(context, ref, lista);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Excluir a lista', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _excluir(context, ref, lista);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listasAsync = ref.watch(listasAtivasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listas', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            key: TutorialKeys.shoppingHistoryButton,
            icon: const Icon(Icons.history),
            tooltip: 'Listas concluídas',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoricoListasScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: listasAsync.when(
                data: (listas) {
                  if (listas.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_basket_outlined, size: 72, color: AppColors.iconMuted(context)),
                            const SizedBox(height: 16),
                            Text('Nenhuma lista ainda.', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 16)),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: listas.length,
                    itemBuilder: (context, index) {
                      final lista = listas[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => _abrirLista(context, ref, lista.id, lista.nome),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lista.nome,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => _showCardMenu(context, ref, lista),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(Icons.more_vert, color: Colors.white70),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: lista.progresso,
                                          minHeight: 10,
                                          backgroundColor: AppColors.divider(context),
                                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text('${lista.marcados}/${lista.total}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Erro: $err')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  key: TutorialKeys.shoppingAddFab,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.divider(context).withOpacity(0.6),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => _criarLista(context, ref),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Criar lista', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
