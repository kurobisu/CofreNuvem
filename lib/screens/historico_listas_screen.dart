import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../providers/listas_compras_provider.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/lista_concluida_delete_dialog.dart';
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

  Future<void> _abrir(BuildContext context, WidgetRef ref, ListaCompras lista) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ListaDetalheScreen(listaId: lista.id, nomeInicial: lista.nome)),
    );
    ref.invalidate(listasConcluidasProvider);
  }

  Future<void> _excluir(BuildContext context, WidgetRef ref, ListaCompras lista) async {
    final valorTransacao = await ListasComprasRepo.valorTransacaoVinculada(lista.id);
    if (!context.mounted) return;
    final confirmou = await confirmarExclusaoListaConcluida(
      context,
      nomeLista: lista.nome,
      valorTransacao: valorTransacao,
    );
    if (!confirmou) return;
    await ListasComprasRepo.excluirConcluida(lista.id, excluirTransacaoVinculada: true);
    ref.invalidate(listasConcluidasProvider);
    ref.invalidate(dashboardDataProvider);
  }

  void _showCardMenu(BuildContext context, WidgetRef ref, ListaCompras lista) {
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
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copiar itens'),
              onTap: () {
                Navigator.pop(ctx);
                _copiar(context, ref, lista);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Excluir lista', style: TextStyle(color: Colors.red)),
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
                    onTap: () => _abrir(context, ref, lista),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(lista.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                if (lista.mercado != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text('🏬 ${lista.mercado}', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13)),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  '${lista.total} itens · ${CurrencyFormatter.format(lista.valorTotal)} · toque para ver',
                                  style: TextStyle(color: AppColors.secondaryText(context), fontSize: 12),
                                ),
                              ],
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
