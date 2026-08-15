import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';
import '../providers/investments_provider.dart';
import '../providers/dashboard_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/app_colors.dart';
import '../database/supabase_helper.dart';
import 'package:flutter/services.dart';
import 'investment_details_screen.dart';

class InvestmentsScreen extends ConsumerStatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  ConsumerState<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends ConsumerState<InvestmentsScreen> {
  bool _showLineChart = false;
  String _chartFilter = 'Mensal';
  
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

  Future<void> _showAddInvestmentDialog() async {
    final db = await SupabaseHelper.instance.database;
    final usuarios = await db.query(SupabaseHelper.tableUsuarios);
    final contas = await db.query(SupabaseHelper.tableContasBancarias);
    final metodos = await db.query(SupabaseHelper.tableMetodosPagamento);
    final investimentosExistentes = await db.query(SupabaseHelper.tableInvestimentos);

    if (usuarios.isEmpty || contas.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre um usuário e uma conta bancária primeiro.')));
      }
      return;
    }

    final nomeController = TextEditingController();
    final valorController = TextEditingController();
    
    bool isNewInvestment = true;
    String? selectedExistingInvestmentId = investimentosExistentes.isNotEmpty ? investimentosExistentes.first['ID'].toString() : null;

    String? selectedUser = usuarios.first['ID']?.toString();
    
    List<Map<String, dynamic>> filteredContas = contas.where((c) => c['Usuario_ID'] == selectedUser).toList();
    String? selectedConta = filteredContas.isNotEmpty ? filteredContas.first['ID'].toString() : null;
    
    String selectedLiquidez = 'Diária';
    final liquidezOptions = ['Diária', 'No Vencimento', 'D+1', 'D+30'];
    String selectedIcon = 'savings';

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void updateTitular(String? val) {
              selectedUser = val;
              filteredContas = contas.where((c) => c['Usuario_ID'] == selectedUser).toList();
              if (!filteredContas.any((c) => c['ID'] == selectedConta)) {
                selectedConta = filteredContas.isNotEmpty ? filteredContas.first['ID'].toString() : null;
              }
            }

            void updateExistingAsset(String? val) {
              selectedExistingInvestmentId = val;
              if (val != null) {
                final inv = investimentosExistentes.firstWhere((i) => i['ID'] == val);
                updateTitular(inv['Usuario_ID'].toString());
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Novo Investimento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    if (investimentosExistentes.isNotEmpty)
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Novo Ativo')),
                          ButtonSegment(value: false, label: Text('Aporte Extra')),
                        ],
                        selected: {isNewInvestment},
                        onSelectionChanged: (val) {
                          setStateDialog(() {
                            isNewInvestment = val.first;
                            if (!isNewInvestment && selectedExistingInvestmentId != null) {
                              updateExistingAsset(selectedExistingInvestmentId);
                            }
                          });
                        },
                      ),
                    
                    const SizedBox(height: 24),
                    
                    if (isNewInvestment) ...[
                      TextField(
                        controller: nomeController,
                        decoration: const InputDecoration(labelText: 'Nome do Ativo (ex: CDB Nubank)'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      Text('Ícone do Ativo', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: investmentIcons.entries.map((e) {
                          final isSelected = selectedIcon == e.key;
                          return InkWell(
                            onTap: () => setStateDialog(() => selectedIcon = e.key),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Colors.transparent,
                                border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : AppColors.divider(context)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(e.value, color: isSelected ? Theme.of(context).colorScheme.primary : AppColors.iconMuted(context)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedLiquidez,
                        items: liquidezOptions.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                        onChanged: (val) => setStateDialog(() => selectedLiquidez = val!),
                        decoration: const InputDecoration(labelText: 'Liquidez'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedUser,
                        items: usuarios.map((u) => DropdownMenuItem<String>(value: u['ID'].toString(), child: Text(u['Nome'].toString()))).toList(),
                        onChanged: (val) => setStateDialog(() => updateTitular(val)),
                        decoration: const InputDecoration(labelText: 'Titular'),
                      ),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedExistingInvestmentId,
                        items: investimentosExistentes.map((i) => DropdownMenuItem<String>(value: i['ID'].toString(), child: Text(i['Ativo'].toString()))).toList(),
                        onChanged: (val) => setStateDialog(() => updateExistingAsset(val)),
                        decoration: const InputDecoration(labelText: 'Ativo Existente'),
                      ),
                    ],

                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedConta,
                      items: filteredContas.map((c) => DropdownMenuItem<String>(value: c['ID'].toString(), child: Text(c['Nome'].toString()))).toList(),
                      onChanged: (val) => setStateDialog(() => selectedConta = val!),
                      decoration: const InputDecoration(labelText: 'Origem do Dinheiro (Conta)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: valorController,
                      decoration: const InputDecoration(labelText: 'Valor Investido'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CurrencyInputFormatter(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          double val = 0;
                          try {
                            final str = valorController.text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
                            val = double.parse(str);
                          } catch(e) {}
                          
                          if (val <= 0) return;
                          if (isNewInvestment && nomeController.text.trim().isEmpty) return;
                          if (selectedConta == null) return;
                          if (!isNewInvestment && selectedExistingInvestmentId == null) return;
                          
                          String insertedInvId;

                          if (isNewInvestment) {
                            insertedInvId = await db.insert(SupabaseHelper.tableInvestimentos, {
                              'Ativo': nomeController.text.trim(),
                              'Data_Aporte': DateTime.now().toIso8601String(),
                              'Valor_Investido': val,
                              'Valor_Atualizado': val,
                              'Liquidez': selectedLiquidez,
                              'Usuario_ID': selectedUser,
                              'Status': 'Ativo',
                              'Icone': selectedIcon,
                            });

                            await db.insert(SupabaseHelper.tableHistoricoRendimentos, {
                              'Investimento_ID': insertedInvId,
                              'Data': DateTime.now().toIso8601String().substring(0, 10),
                              'Valor': val,
                            });
                          } else {
                            insertedInvId = selectedExistingInvestmentId!;
                            final inv = investimentosExistentes.firstWhere((i) => i['ID'] == insertedInvId);
                            final novoValorInvestido = (inv['Valor_Investido'] as num).toDouble() + val;
                            final novoValorAtualizado = (inv['Valor_Atualizado'] as num).toDouble() + val;

                            await db.update(SupabaseHelper.tableInvestimentos, {
                              'Valor_Investido': novoValorInvestido,
                              'Valor_Atualizado': novoValorAtualizado,
                            }, where: 'ID = ?', whereArgs: [insertedInvId]);

                            await db.insert(SupabaseHelper.tableHistoricoRendimentos, {
                              'Investimento_ID': insertedInvId,
                              'Data': DateTime.now().toIso8601String().substring(0, 10),
                              'Valor': novoValorAtualizado,
                            });
                          }
                          
                          String? categoriaInvestimentoId;
                          final catRes = await db.query(SupabaseHelper.tableCategorias, where: "Nome = 'Investimentos'");
                          if (catRes.isEmpty) {
                            categoriaInvestimentoId = await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Investimentos', 'Cor_Hexadecimal': '#4CAF50', 'Tipo': 'Despesa'});
                          } else {
                            categoriaInvestimentoId = catRes.first['ID'].toString();
                          }

                          String? metodoId = metodos.where((m) => m['Conta_ID'] == selectedConta).firstOrNull?['ID']?.toString();
                          if (metodoId == null && metodos.isNotEmpty) {
                              metodoId = metodos.first['ID'].toString();
                          }

                          await db.insert(SupabaseHelper.tableTransacoes, {
                            'Descricao': 'Aporte - ${isNewInvestment ? nomeController.text.trim() : investimentosExistentes.firstWhere((i) => i['ID'] == insertedInvId)['Ativo']}',
                            'Valor': val,
                            'Data': DateTime.now().toIso8601String(),
                            'Tipo': 'Despesa',
                            'Usuario_ID': selectedUser,
                            'Conta_ID': selectedConta,
                            'Metodo_ID': metodoId,
                            'Categoria_ID': categoriaInvestimentoId,
                            'Paga': 1,
                            'Investimento_ID': insertedInvId,
                          });
                          
                          if (mounted) {
                            Navigator.pop(context);
                            ref.refresh(investmentsProvider);
                            ref.refresh(investmentHistoryProvider);
                            ref.refresh(dashboardDataProvider);
                          }
                        },
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: const Text('Salvar Investimento'),
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

  Future<void> _showUpdateYieldDialog(List<Map<String, dynamic>> investments) async {
    if (investments.isEmpty) return;
    
    // Map of ID to its new text controller
    Map<String, TextEditingController> controllers = {};
    for (var inv in investments) {
      controllers[inv['ID']] = TextEditingController(text: CurrencyFormatter.format(inv['Valor_Atualizado']));
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Atualizar Rendimentos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: investments.length,
                    itemBuilder: (context, index) {
                      final inv = investments[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: TextField(
                          controller: controllers[inv['ID']],
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CurrencyInputFormatter(),
                          ],
                          decoration: InputDecoration(
                            labelText: inv['Ativo'],
                            helperText: 'Titular: ${inv['UsuarioNome']} • Investido: ${CurrencyFormatter.format(inv['Valor_Investido'])}',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final db = await SupabaseHelper.instance.database;
                        final now = DateTime.now().toIso8601String().substring(0, 10);
                        
                        for (var inv in investments) {
                          double newVal = 0;
                          try {
                            final str = controllers[inv['ID']]!.text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
                            newVal = double.parse(str);
                          } catch(e) {}
                          
                          if (newVal > 0 && newVal != inv['Valor_Atualizado']) {
                            // Update Current Value
                            await db.update(
                              SupabaseHelper.tableInvestimentos,
                              {'Valor_Atualizado': newVal},
                              where: 'ID = ?',
                              whereArgs: [inv['ID']],
                            );
                            
                            // Save to History
                            await db.insert(SupabaseHelper.tableHistoricoRendimentos, {
                              'Investimento_ID': inv['ID'],
                              'Data': now,
                              'Valor': newVal,
                            });
                          }
                        }

                        if (mounted) {
                          Navigator.pop(context);
                          ref.refresh(investmentsProvider);
                          ref.refresh(investmentHistoryProvider);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rendimentos atualizados com sucesso! 🚀')));
                        }
                      },
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text('Salvar Tudo'),
                    ),
                  ),
                )
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildLineChart(List<Map<String, dynamic>> history, List<Color> colors, bool isDark) {
    if (history.isEmpty) return const SizedBox(height: 200, child: Center(child: Text('Sem dados históricos')));

    Map<String, List<FlSpot>> grouped = {};
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = 0; // comece do 0 para melhor percepção visual
    double maxY = double.negativeInfinity;

    for (var row in history) {
      final ativo = row['Ativo'].toString();
      final dateStr = row['Data'].toString();
      final date = DateTime.parse(dateStr);
      final double valor = (row['Valor'] as num?)?.toDouble() ?? 0.0;
      
      double x = date.millisecondsSinceEpoch.toDouble();
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (valor > maxY) maxY = valor;

      if (!grouped.containsKey(ativo)) grouped[ativo] = [];
      grouped[ativo]!.add(FlSpot(x, valor));
    }

    if (minX == maxX) {
      minX -= 86400000; // -1 dia
      maxX += 86400000; // +1 dia
    }
    
    // Add 10% padding to maxY
    if (maxY == 0) maxY = 100;
    maxY *= 1.1;

    int i = 0;
    List<LineChartBarData> lines = grouped.entries.map((e) {
      final c = colors[i++ % colors.length];
      return LineChartBarData(
        spots: e.value,
        isCurved: true,
        color: c,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: c, strokeWidth: 1.5, strokeColor: Colors.white)),
        belowBarData: BarAreaData(show: true, color: c.withOpacity(0.1)),
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              lineBarsData: lines,
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: (maxX - minX) / 5 < 86400000 ? 86400000 : (maxX - minX) / 5,
                    getTitlesWidget: (value, meta) {
                      final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                      String text;
                      if (_chartFilter == 'Anual') {
                        text = dt.year.toString();
                      } else if (_chartFilter == 'Mensal') {
                        text = '${dt.month}/${dt.year}';
                      } else {
                        text = '${dt.day}/${dt.month}';
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(text, style: TextStyle(fontSize: 10, color: AppColors.mutedText(context))),
                      );
                    }
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: () {
            int j = 0;
            return grouped.entries.map((e) {
              final c = colors[j++ % colors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(e.key, style: const TextStyle(fontSize: 12)),
                ],
              );
            }).toList();
          }()
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final investmentsAsync = ref.watch(investmentsProvider);
    final historyAsync = ref.watch(investmentHistoryProvider);
    final isBalanceHidden = ref.watch(hideBalanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Investimentos', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isBalanceHidden ? Icons.visibility_off : Icons.visibility),
            tooltip: isBalanceHidden ? 'Mostrar Saldos' : 'Ocultar Saldos',
            onPressed: () => ref.read(hideBalanceProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Novo Investimento',
            onPressed: _showAddInvestmentDialog,
          )
        ],
      ),
      body: investmentsAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined, size: 80, color: AppColors.iconMuted(context)),
                  const SizedBox(height: 16),
                  const Text('Nenhum investimento registrado.'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showAddInvestmentDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Começar a Investir'),
                  )
                ],
              ),
            );
          }

          double totalInvestido = 0;
          double patrimonioAtualizado = 0;
          Map<String, double> assetAllocation = {};

          for (var item in data) {
            double atualizado = ((item['Valor_Atualizado'] ?? item['valor_atualizado'] ?? item['Valor_Investido'] ?? item['valor_investido'] ?? 0) as num).toDouble();
            double investido = ((item['Valor_Investido'] ?? item['valor_investido'] ?? 0) as num).toDouble();
            totalInvestido += investido;
            patrimonioAtualizado += atualizado;
            final String nomeAtivo = (item['Ativo'] ?? item['ativo'] ?? 'Outros').toString();
            assetAllocation[nomeAtivo] = (assetAllocation[nomeAtivo] ?? 0) + atualizado;
          }

          final double rendimento = patrimonioAtualizado - totalInvestido;
          final double rendimentoPct = totalInvestido > 0 ? (rendimento / totalInvestido) * 100 : 0;
          
          final List<Color> colors = [Colors.blue, Colors.purple, Colors.orange, Colors.teal, Colors.pink, Colors.amber];
          int colorIdx = 0;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary.withOpacity(0.8),
                              Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Patrimônio Atualizado', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                            const SizedBox(height: 8),
                            Text(
                              isBalanceHidden ? 'R\$ ••••••' : CurrencyFormatter.format(patrimonioAtualizado),
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Investido', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                                    Text(isBalanceHidden ? 'R\$ ••••••' : CurrencyFormatter.format(totalInvestido), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Rendimento Líquido', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: rendimento >= 0 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isBalanceHidden ? '••••••' : '${rendimento >= 0 ? '+' : ''}${CurrencyFormatter.format(rendimento)} (${rendimentoPct.toStringAsFixed(2)}%)',
                                        style: TextStyle(
                                          color: rendimento >= 0 ? Colors.greenAccent : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              if (assetAllocation.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_showLineChart) ...[
                              DropdownButton<String>(
                                value: _chartFilter,
                                items: ['Diário', 'Semanal', 'Mensal', 'Anual'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                onChanged: (v) => setState(() => _chartFilter = v!),
                                underline: const SizedBox(),
                              ),
                              const SizedBox(width: 16),
                            ],
                            IconButton(
                              icon: Icon(_showLineChart ? Icons.pie_chart : Icons.show_chart, color: Theme.of(context).colorScheme.primary),
                              onPressed: () => setState(() => _showLineChart = !_showLineChart),
                              tooltip: 'Trocar Visualização',
                            ),
                          ],
                        ),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(color: AppColors.divider(context)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _showLineChart 
                              ? historyAsync.when(
                                  data: (historyData) => _buildLineChart(historyData, colors, isDark),
                                  loading: () => const Center(child: CircularProgressIndicator()),
                                  error: (err, stack) => const Text('Erro ao carregar histórico'),
                                )
                              : Row(
                                  children: [
                                    SizedBox(
                                      height: 100,
                                      width: 100,
                                      child: PieChart(
                                        PieChartData(
                                          sectionsSpace: 2,
                                          centerSpaceRadius: 20,
                                          sections: assetAllocation.entries.map((e) {
                                            final c = colors[colorIdx++ % colors.length];
                                            return PieChartSectionData(
                                              color: c,
                                              value: e.value,
                                              title: '',
                                              radius: 20,
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: () {
                                          int i = 0;
                                          return assetAllocation.entries.map((e) {
                                            final c = colors[i++ % colors.length];
                                            final double pct = (e.value / patrimonioAtualizado) * 100;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 4.0),
                                              child: Row(
                                                children: [
                                                  Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                                  Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: AppColors.mutedText(context))),
                                                ],
                                              ),
                                            );
                                          }).toList();
                                        }(),
                                      ),
                                    )
                                  ],
                                ),
                          ),
                        ),
                      ],
                    ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = data[index];
                      final double valInv = ((item['Valor_Investido'] ?? item['valor_investido'] ?? 0) as num).toDouble();
                      final double valAtu = ((item['Valor_Atualizado'] ?? item['valor_atualizado'] ?? valInv) as num).toDouble();
                      final double lucro = valAtu - valInv;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider(context)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvestmentDetailsScreen(investmentId: item['ID'].toString()))),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12)
                                    ),
                                    child: Icon(investmentIcons[item['Icone']] ?? Icons.savings, color: Theme.of(context).colorScheme.primary),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['Ativo'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Text('Titular: ${item['UsuarioNome']}', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context))),
                                        Text('Liq: ${item['Liquidez']}', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context))),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(isBalanceHidden ? 'R\$ ••••••' : CurrencyFormatter.format(valAtu), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text(
                                        isBalanceHidden ? '••••••' : '${lucro >= 0 ? '+' : ''}${CurrencyFormatter.format(lucro)}',
                                        style: TextStyle(
                                          color: lucro >= 0 ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    },
                    childCount: data.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final data = investmentsAsync.value;
          if (data != null && data.isNotEmpty) {
            _showUpdateYieldDialog(data);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre um investimento primeiro.')));
          }
        },
        icon: const Icon(Icons.update),
        label: const Text('Atualizar Rendimento'),
      ),
    );
  }
}
