import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/dashboard_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/bancos_brasil.dart';
import '../theme/app_theme.dart';
import '../database/supabase_helper.dart';
import 'invoices_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'transaction_form_screen.dart';
import '../utils/transaction_helper.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsyncValue = ref.watch(dashboardDataProvider);
    final isBalanceHidden = ref.watch(hideBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visão Geral'),
        actions: [
          IconButton(
            icon: Icon(isBalanceHidden ? Icons.visibility_off : Icons.visibility),
            tooltip: isBalanceHidden ? 'Mostrar Saldos' : 'Ocultar Saldos',
            onPressed: () => ref.read(hideBalanceProvider.notifier).toggle(),
          ),
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
                  _buildTotalBalanceCard(context, totalBalance, isBalanceHidden),
                  const SizedBox(height: 24),
                  _buildUserBalancesList(userBalances, isBalanceHidden),
                  const SizedBox(height: 24),
                  if (creditCards.isNotEmpty) ...[
                    _buildCreditCardsRow(context, creditCards),
                    const SizedBox(height: 24),
                  ],
                  if (categoryExpenses.isNotEmpty) _buildExpensesChart(context, categoryExpenses),
                  const SizedBox(height: 24),
                  _buildRecentTransactions(context, ref, recentTransactions),
                  const SizedBox(height: 120), // padding for FAB/BottomNav
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

  Widget _buildTotalBalanceCard(BuildContext context, double totalBalance, bool isHidden) {
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
            isHidden ? 'R\$ ••••••' : CurrencyFormatter.format(totalBalance),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBalancesList(List<Map<String, dynamic>> userBalances, bool isHidden) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: userBalances.length,
      itemBuilder: (context, index) {
        final ub = userBalances[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: InkWell(
            onTap: () => _showUserReportModal(context, ub['id'].toString(), ub['nome'] as String),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.accent.withOpacity(0.2),
                    child: Text(
                      ub['nome'].toString().substring(0, 1),
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ub['nome'],
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isHidden ? 'R\$ ••••••' : CurrencyFormatter.format(ub['saldo']),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
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

  Future<void> _deleteTransaction(BuildContext context, WidgetRef ref, String id) async {
    await TransactionHelper.deleteTransactionWithConfirmation(context, id, ref, () {
      ref.refresh(dashboardDataProvider);
    });
  }

  Future<void> _showReceiptModal(BuildContext context, int transacaoId, String transacaoTitle) async {
    final db = await SupabaseHelper.instance.database;
    final items = await db.query(SupabaseHelper.tableListaCompras, where: 'Transacao_ID = ?', whereArgs: [transacaoId]);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Column(
              children: [
                const SizedBox(height: 16),
                const Icon(Icons.receipt_long, size: 48, color: Colors.green),
                const SizedBox(height: 8),
                Text('Cupom Fiscal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(transacaoTitle, style: const TextStyle(color: Colors.grey)),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final preco = item['Preco'] as num;
                      final qtde = item['Quantidade'] as num;
                      final total = preco * qtde;
                      return ListTile(
                        title: Text(item['Nome'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${qtde.toString().replaceAll('.0', '')}x de ${CurrencyFormatter.format(preco.toDouble())}'),
                        trailing: Text(CurrencyFormatter.format(total.toDouble()), style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTransactionOptions(BuildContext context, WidgetRef ref, Map<String, dynamic> t) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(t['Descricao'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Text('Opções da Transação', style: TextStyle(color: Colors.grey)),
              const Divider(),
              if ((t['HasItems'] ?? 0) > 0)
                ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.green),
                  title: const Text('Ver Cupom Fiscal (Itens da Compra)'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReceiptModal(context, t['ID'], t['Descricao']);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Editar Transação'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransactionFormScreen(transactionId: t['ID']),
                    ),
                  ).then((_) => ref.refresh(dashboardDataProvider));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Excluir Transação'),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Excluir Transação?'),
                      content: const Text('Esta ação não pode ser desfeita.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deleteTransaction(context, ref, t['ID']);
                          },
                          child: const Text('Excluir'),
                        )
                      ],
                    )
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  Widget _buildRecentTransactions(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> transactions) {
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
              final isPaga = t['Paga'] == 1;
              
              final bancoCode = t['Codigo_Banco']?.toString() ?? '999';
              final banco = BancosBrasil.obterBancoPorCodigo(bancoCode);
              final bancoColor = Color(int.parse(banco.colorHex.replaceAll('#', '0xFF')));
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: isPaga ? null : BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.orange.withOpacity(0.6), blurRadius: 12, spreadRadius: 1),
                  ],
                ),
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isPaga ? BorderSide.none : const BorderSide(color: Colors.orange, width: 1.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showTransactionOptions(context, ref, t),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Stack(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: bancoColor, borderRadius: BorderRadius.circular(12)),
                            child: Icon(banco.iconData ?? Icons.account_balance, color: Colors.white, size: 24),
                          ),
                          if (!isPaga)
                            Positioned(
                              right: -2, top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: const Icon(Icons.warning, color: Colors.orange, size: 14),
                              ),
                            )
                        ],
                      ),
                      title: Text(t['Descricao'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(t['CategoriaNome'].toString() + ' • ' + banco.nome + ' (' + (t['MetodoNome'] ?? '') + ')'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isReceita ? '+' : '-'} ${CurrencyFormatter.format(t['Valor'])}',
                            style: TextStyle(
                              color: isReceita ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (!isPaga)
                            const Text('Pendente', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _showUserReportModal(BuildContext context, String userId, String userName) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchUserReport(userId),
          builder: (context, snapshot) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Relatório de Pagamentos • $userName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(),
                  Expanded(
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : snapshot.hasError
                            ? Center(child: Text('Erro: ${snapshot.error}'))
                            : _buildReportContent(context, snapshot.data ?? []),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUserReport(String userId) async {
    final db = await SupabaseHelper.instance.database;
    return await db.rawQuery('''
      SELECT 
        c.Nome as ContaNome, 
        c.Codigo_Banco,
        m.Nome as MetodoNome, 
        t.Tipo,
        SUM(t.Valor) as Total
      FROM ${SupabaseHelper.tableTransacoes} t
      JOIN ${SupabaseHelper.tableContasBancarias} c ON t.Conta_ID = c.ID
      JOIN ${SupabaseHelper.tableMetodosPagamento} m ON t.Metodo_ID = m.ID
      WHERE t.Usuario_ID = ? AND t.Paga = 1
      GROUP BY c.Nome, m.Nome, t.Tipo
      ORDER BY c.Nome, m.Nome, t.Tipo
    ''', [userId]);
  }

  Widget _buildReportContent(BuildContext context, List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const Center(child: Text('Nenhuma movimentação encontrada.'));

    Map<String, List<Map<String, dynamic>>> groupedByAccount = {};
    double totalDespesas = 0.0;
    Map<String, double> metodosTotals = {};

    for (var row in data) {
      String account = row['ContaNome'];
      if (!groupedByAccount.containsKey(account)) {
        groupedByAccount[account] = [];
      }
      groupedByAccount[account]!.add(row);

      if (row['Tipo'] == 'Despesa') {
        totalDespesas += row['Total'];
        String met = row['MetodoNome'];
        metodosTotals[met] = (metodosTotals[met] ?? 0.0) + row['Total'];
      }
    }

    final List<Color> colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink];
    int colorIdx = 0;

    return CustomScrollView(
      slivers: [
        if (totalDespesas > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                elevation: 0,
                color: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Consumo por Método', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 150,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: metodosTotals.entries.map((e) {
                              final double pct = (e.value / totalDespesas) * 100;
                              final c = colors[colorIdx++ % colors.length];
                              return PieChartSectionData(
                                color: c,
                                value: e.value,
                                title: '${pct.toStringAsFixed(0)}%',
                                radius: 45,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: () {
                          int i = 0;
                          return metodosTotals.entries.map((e) {
                            final c = colors[i++ % colors.length];
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text(e.key, style: const TextStyle(fontSize: 12)),
                              ],
                            );
                          }).toList();
                        }(),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              String accountName = groupedByAccount.keys.elementAt(index);
              List<Map<String, dynamic>> items = groupedByAccount[accountName]!;
              
              final bancoCode = items.first['Codigo_Banco']?.toString() ?? '999';
              final banco = BancosBrasil.obterBancoPorCodigo(bancoCode);
              final bancoColor = Color(int.parse(banco.colorHex.replaceAll('#', '0xFF')));

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: bancoColor.withOpacity(0.1),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          children: [
                            Icon(banco.iconData ?? Icons.account_balance, color: bancoColor),
                            const SizedBox(width: 8),
                            Text(accountName, style: TextStyle(fontWeight: FontWeight.bold, color: bancoColor, fontSize: 16)),
                          ],
                        ),
                      ),
                      ...items.map((row) {
                        bool isReceita = row['Tipo'] == 'Receita';
                        return ListTile(
                          title: Text(row['MetodoNome'], style: const TextStyle(fontSize: 16)),
                          trailing: Text(
                            (isReceita ? '+ ' : '- ') + CurrencyFormatter.format(row['Total']),
                            style: TextStyle(
                              color: isReceita ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
            childCount: groupedByAccount.length,
          ),
        ),
      ],
    );
  }
}
