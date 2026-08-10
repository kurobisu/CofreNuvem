import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/investments_provider.dart';
import '../utils/currency_formatter.dart';

class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investmentsAsyncValue = ref.watch(investmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investimentos'),
      ),
      body: investmentsAsyncValue.when(
        data: (data) {
          if (data.isEmpty) {
            return const Center(child: Text('Nenhum investimento registrado.'));
          }

          double totalInvestido = 0;
          double patrimonioAtualizado = 0;

          for (var item in data) {
            totalInvestido += item['Valor_Investido'];
            patrimonioAtualizado += item['Valor_Atualizado'];
          }

          final double rendimento = patrimonioAtualizado - totalInvestido;
          final double rendimentoPct = totalInvestido > 0 ? (rendimento / totalInvestido) * 100 : 0;

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Patrimônio Atualizado', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.format(patrimonioAtualizado),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Investido', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(CurrencyFormatter.format(totalInvestido), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Rendimento', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              '${rendimento >= 0 ? '+' : ''}${CurrencyFormatter.format(rendimento)} (${rendimentoPct.toStringAsFixed(2)}%)',
                              style: TextStyle(
                                color: rendimento >= 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Icon(Icons.show_chart, color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(item['Ativo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Titular: ${item['UsuarioNome']} • Liq: ${item['Liquidez']}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(CurrencyFormatter.format(item['Valor_Atualizado']), style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Inv: ${CurrencyFormatter.format(item['Valor_Investido'])}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Open dialog to update Rendimentos or add new investment
        },
        icon: const Icon(Icons.update),
        label: const Text('Atualizar Rendimento'),
      ),
    );
  }
}
