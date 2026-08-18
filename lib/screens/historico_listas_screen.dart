import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/listas_compras_provider.dart';
import '../utils/app_colors.dart';
import 'historico_lista_detalhe_screen.dart';
import 'lista_detalhe_screen.dart';

class HistoricoListasScreen extends ConsumerWidget {
  const HistoricoListasScreen({super.key});

  Future<void> _copiar(BuildContext context, WidgetRef ref, ListaCompras lista) async {
    final novoId = await ListasComprasRepo.copiarParaNovaLista(lista.id, lista.nome);
    ref.invalidate(listasAtivasProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nova lista "${lista.nome}" criada com os itens de antes!')));
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ListaDetalheScreen(listaId: novoId, nomeInicial: lista.nome)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listasAsync = ref.watch(listasConcluidasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Listas Concluídas')),
      body: listasAsync.when(
        data: (listas) {
          if (listas.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: AppColors.iconMuted(context)),
                    const SizedBox(height: 16),
                    Text('Nenhuma lista concluída ainda.', style: TextStyle(color: AppColors.secondaryText(context))),
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => HistoricoListaDetalheScreen(listaId: lista.id, nomeLista: lista.nome)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(lista.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text('${lista.total} itens · toque para ver', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 12)),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _copiar(context, ref, lista),
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copiar itens'),
                          ),
                        ],
                      ),
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
    );
  }
}
