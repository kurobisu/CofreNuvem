import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/dashboard_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/bancos_brasil.dart';
import '../theme/app_theme.dart';
import 'invoices_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsyncValue = ref.watch(dashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visão Geral'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Relatórios Avançados',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: dashboardAsyncValue.when(
        data: (data) {
          final totalBalance = data['totalBalance'] as double;
          final userBalances = data['userBalances'] as List<Map<String, dynamic>>;
          final categoryExpenses = data['categoryExpenses'] as List<Map<String, dynamic>>;
          final recentTransactions = data['recentTransactions'] as List<Map<String, dynamic>>;
          final creditCards = (data['creditCards'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

          return RefreshIndicator(
            onRefresh: () => ref.refresh(dashboardDataProvider.future),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTotalBalanceCard(context, totalBalance),
                  const SizedBox(height: 24),
                  _buildUserBalancesRow(userBalances),
                  const SizedBox(height: 24),
                  if (creditCards.isNotEmpty) ...[
                    _buildCreditCardsRow(context, creditCards),
                    const SizedBox(height: 24),
                  ],
                  if (categoryExpenses.isNotEmpty) _buildExpensesChart(context, categoryExpenses),
                  const SizedBox(height: 24),
                  _buildRecentTransactions(context, recentTransactions),
                  const SizedBox(height: 80), // padding for FAB/BottomNav
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro ao carregar dados: $err')),
      ),
    );
  }

  Widget _buildTotalBalanceCard(BuildContext context, double totalBalance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo Familiar Total',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(totalBalance),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBalancesRow(List<Map<String, dynamic>> userBalances) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: userBalances.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final ub = userBalances[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.accent.withOpacity(0.2),
                    child: Text(
                      ub['nome'].toString().substring(0, 1),
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ub['nome'],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(ub['saldo']),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreditCardsRow(BuildContext context, List<Map<String, dynamic>> creditCards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cartões & Faturas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 100, // Increased height to prevent overflow and fit new info
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: creditCards.length,
            itemBuilder: (context, index) {
              final card = creditCards[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoicesScreen(metodo: card))),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.credit_card, color: AppTheme.accent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(card['BancoNome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        const Spacer(),
                        Text(card['Nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${card['UsuarioNome']} • Fecha dia ${card['Dia_Fechamento']}', style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpensesChart(BuildContext context, List<Map<String, dynamic>> categoryExpenses) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Despesas por Categoria (Mês)', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: categoryExpenses.map((e) {
                    final colorHex = e['Cor_Hexadecimal'].toString().replaceAll('#', '0xFF');
                    return PieChartSectionData(
                      color: Color(int.parse(colorHex)),
                      value: e['total'],
                      title: '', // Hiding titles on chart, will show in legend
                      radius: 35,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: categoryExpenses.take(5).map((e) { // Top 5 in legend
                final colorHex = e['Cor_Hexadecimal'].toString().replaceAll('#', '0xFF');
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(int.parse(colorHex)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${e['Nome']} (${CurrencyFormatter.format(e['total'])})', style: const TextStyle(fontSize: 12)),
                  ],
                );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context, List<Map<String, dynamic>> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Últimas Transações', style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/history'), 
              child: const Text('Ver tudo')
            ),
          ],
        ),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Nenhuma transação registrada')),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final t = transactions[index];
              final isReceita = t['Tipo'] == 'Receita';
              
              final bancoCode = t['Codigo_Banco']?.toString() ?? '999';
              final banco = BancosBrasil.obterBancoPorCodigo(bancoCode);
              final bancoColor = Color(int.parse(banco.colorHex.replaceAll('#', '0xFF')));
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: bancoColor, borderRadius: BorderRadius.circular(12)),
                    child: Icon(banco.iconData ?? Icons.account_balance, color: Colors.white, size: 24),
                  ),
                  title: Text(t['Descricao'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(t['CategoriaNome'].toString() + ' • ' + banco.nome + ' (' + (t['MetodoNome'] ?? '') + ')'),
                  trailing: Text(
                    (isReceita ? '+ ' : '- ') + CurrencyFormatter.format(t['Valor']),
                    style: TextStyle(
                      color: isReceita ? Colors.green : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
