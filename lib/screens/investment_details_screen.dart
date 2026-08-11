import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../providers/investment_details_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/investments_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import '../database/database_helper.dart';

class InvestmentDetailsScreen extends ConsumerStatefulWidget {
  final int investmentId;
  const InvestmentDetailsScreen({super.key, required this.investmentId});

  @override
  ConsumerState<InvestmentDetailsScreen> createState() => _InvestmentDetailsScreenState();
}

class _InvestmentDetailsScreenState extends ConsumerState<InvestmentDetailsScreen> {
  final Map<String, IconData> investmentIcons = {
    'savings': Icons.savings,
    'trending_up': Icons.trending_up,
    'business': Icons.business,
    'attach_money': Icons.attach_money,
    'apartment': Icons.apartment,
    'account_balance': Icons.account_balance,
    'show_chart': Icons.show_chart,
    'pie_chart': Icons.pie_chart,
  };

  Future<void> _showRedeemInvestmentDialog(Map<String, dynamic> item) async {
    final db = await DatabaseHelper.instance.database;
    final contas = await db.query(DatabaseHelper.tableContasBancarias, where: 'Usuario_ID = ?', whereArgs: [item['Usuario_ID']]);
    final metodos = await db.query(DatabaseHelper.tableMetodosPagamento);

    if (contas.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma conta bancária cadastrada.')));
      return;
    }

    final valorController = TextEditingController();
    int? selectedConta = contas.first['ID'] as int?;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Resgatar ${item['Ativo']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Saldo Atual: ${CurrencyFormatter.format(item['Valor_Atualizado'])}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedConta,
                      items: contas.map((c) => DropdownMenuItem<int>(value: c['ID'] as int, child: Text(c['Nome'].toString()))).toList(),
                      onChanged: (val) => setStateDialog(() => selectedConta = val!),
                      decoration: const InputDecoration(labelText: 'Conta Destino (Crédito)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: valorController,
                      decoration: const InputDecoration(labelText: 'Valor a Resgatar'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CurrencyInputFormatter(),
                      ],
                      onChanged: (text) {
                        double valResgate = 0;
                        try {
                          final str = text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
                          valResgate = double.parse(str);
                        } catch(e) {}
                        
                        double maxDisp = item['Valor_Atualizado'];
                        if (valResgate > maxDisp) {
                          final maxStr = CurrencyFormatter.format(maxDisp);
                          valorController.value = TextEditingValue(
                            text: maxStr,
                            selection: TextSelection.collapsed(offset: maxStr.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          double valResgate = 0;
                          try {
                            final str = valorController.text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
                            valResgate = double.parse(str);
                          } catch(e) {}
                          
                          double maxDisp = item['Valor_Atualizado'];
                          if (valResgate <= 0 || valResgate > maxDisp) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valor de resgate inválido.')));
                            return;
                          }
                          if (selectedConta == null) return;
                          
                          double proporcao = valResgate / maxDisp;
                          double valInvestidoAbatido = item['Valor_Investido'] * proporcao;
                          
                          double novoAtualizado = maxDisp - valResgate;
                          double novoInvestido = item['Valor_Investido'] - valInvestidoAbatido;
                          
                          if (novoAtualizado < 0.01) {
                            // Soft Delete (Status = 'Resgatado')
                            await db.update(DatabaseHelper.tableInvestimentos, {
                              'Valor_Investido': 0.0,
                              'Valor_Atualizado': 0.0,
                              'Status': 'Resgatado'
                            }, where: 'ID = ?', whereArgs: [item['ID']]);
                          } else {
                            await db.update(DatabaseHelper.tableInvestimentos, {
                              'Valor_Investido': novoInvestido,
                              'Valor_Atualizado': novoAtualizado,
                            }, where: 'ID = ?', whereArgs: [item['ID']]);
                            
                            await db.insert(DatabaseHelper.tableHistoricoRendimentos, {
                              'Investimento_ID': item['ID'],
                              'Data': DateTime.now().toIso8601String().substring(0, 10),
                              'Valor': novoAtualizado,
                            });
                          }
                          
                          int? categoriaInvestimentoId;
                          final catRes = await db.query(DatabaseHelper.tableCategorias, where: "Nome = 'Resgate de Investimento'");
                          if (catRes.isEmpty) {
                            categoriaInvestimentoId = await db.insert(DatabaseHelper.tableCategorias, {'Nome': 'Resgate de Investimento', 'Cor_Hexadecimal': '#8BC34A', 'Tipo': 'Receita'});
                          } else {
                            categoriaInvestimentoId = catRes.first['ID'] as int;
                          }

                          int? metodoId = metodos.where((m) => m['Conta_ID'] == selectedConta).firstOrNull?['ID'] as int?;
                          if (metodoId == null && metodos.isNotEmpty) {
                              metodoId = metodos.first['ID'] as int;
                          }

                          await db.insert(DatabaseHelper.tableTransacoes, {
                            'Descricao': 'Resgate - ${item['Ativo']}',
                            'Valor': valResgate,
                            'Data': DateTime.now().toIso8601String(),
                            'Tipo': 'Receita',
                            'Usuario_ID': item['Usuario_ID'],
                            'Conta_ID': selectedConta,
                            'Metodo_ID': metodoId,
                            'Categoria_ID': categoriaInvestimentoId,
                            'Paga': 1,
                            'Investimento_ID': item['ID'],
                          });
                          
                          if (mounted) {
                            Navigator.pop(context);
                            ref.refresh(investmentDetailsProvider(widget.investmentId));
                            ref.refresh(investmentsProvider);
                            ref.refresh(investmentHistoryProvider);
                            ref.refresh(dashboardDataProvider);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resgate realizado com sucesso!')));
                            if (novoAtualizado < 0.01) {
                              Navigator.pop(context); // Close details screen if fully redeemed
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Confirmar Resgate'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildLineChart(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return const SizedBox(height: 200, child: Center(child: Text('Sem dados históricos')));

    List<FlSpot> spots = [];
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = 0;
    double maxY = double.negativeInfinity;

    for (var row in history) {
      final dateStr = row['Data'].toString();
      final date = DateTime.parse(dateStr);
      final double valor = (row['Valor'] as num?)?.toDouble() ?? 0.0;
      
      double x = date.millisecondsSinceEpoch.toDouble();
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (valor > maxY) maxY = valor;

      spots.add(FlSpot(x, valor));
    }

    if (minX == maxX) {
      minX -= 86400000; // -1 dia
      maxX += 86400000; // +1 dia
    }
    
    if (maxY == 0) maxY = 100;
    maxY *= 1.1;

    LineChartBarData line = LineChartBarData(
      spots: spots,
      isCurved: true,
      color: Colors.blueAccent,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.1)),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Evolução do Saldo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                lineBarsData: [line],
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: max(86400000, (maxX - minX) / 5),
                      getTitlesWidget: (value, meta) {
                        final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                        String text = '${dt.day}/${dt.month}';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        );
                      }
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(investmentDetailsProvider(widget.investmentId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Detalhes do Investimento', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: asyncData.when(
        data: (data) {
          final investment = data['investment'];
          final List<Map<String, dynamic>> history = List<Map<String, dynamic>>.from(data['history']);
          final List<Map<String, dynamic>> transactions = List<Map<String, dynamic>>.from(data['transactions']);

          final double valInv = (investment['Valor_Investido'] as num).toDouble();
          final double valAtu = (investment['Valor_Atualizado'] as num).toDouble();
          final double lucro = valAtu - valInv;
          
          double totalAportado = 0;
          double totalResgatado = 0;
          
          for (var t in transactions) {
            if (t['Tipo'] == 'Despesa') totalAportado += t['Valor'];
            if (t['Tipo'] == 'Receita') totalResgatado += t['Valor'];
          }

          final String iconeKey = investment['Icone'] ?? 'savings';
          final IconData iconData = investmentIcons[iconeKey] ?? Icons.savings;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Icon(iconData, size: 36, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(investment['Ativo'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: investment['Status'] == 'Resgatado' ? Colors.grey.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16)
                        ),
                        child: Text(
                          investment['Status'], 
                          style: TextStyle(
                            color: investment['Status'] == 'Resgatado' ? Colors.grey : Colors.greenAccent, 
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.withOpacity(0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Saldo Atual', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  Text(CurrencyFormatter.format(valAtu), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.withOpacity(0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Rendimento Líquido', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${lucro >= 0 ? '+' : ''}${CurrencyFormatter.format(lucro)}', 
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: lucro >= 0 ? Colors.green : Colors.red)
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('Histórico de Movimentações', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 8),
                          Text('Total Aportado: ${CurrencyFormatter.format(totalAportado)}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildLineChart(history),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              
              if (transactions.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('Nenhuma movimentação associada', style: TextStyle(color: Colors.grey))),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final t = transactions[index];
                        final isAporte = t['Tipo'] == 'Despesa'; // Aporte é despesa da conta
                        final icon = isAporte ? Icons.call_made : Icons.call_received;
                        final color = isAporte ? Colors.blueAccent : Colors.orangeAccent;
                        final dt = DateTime.parse(t['Data'].toString());
                        final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(dt);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.1),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          title: Text(isAporte ? 'Aporte' : 'Resgate', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${t['ContaNome']} • $dateStr', style: const TextStyle(fontSize: 12)),
                          trailing: Text(
                            '${isAporte ? '+' : '-'}${CurrencyFormatter.format(t['Valor'])}', 
                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)
                          ),
                        );
                      },
                      childCount: transactions.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
      floatingActionButton: asyncData.value?['investment']['Status'] == 'Ativo' ? FloatingActionButton.extended(
        onPressed: () => _showRedeemInvestmentDialog(asyncData.value!['investment']),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.money_off),
        label: const Text('Resgatar'),
      ) : null,
    );
  }
}
