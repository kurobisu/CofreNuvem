import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/supabase_helper.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/app_colors.dart';


class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  String _selectedMonth = '';
  List<String> _availableMonths = [];

  // Data
  Map<String, double> _categoryTotals = {};
  Map<String, String> _categoryColors = {};
  double _totalExpenses = 0.0;

  // New stacked chart data
  // Per Bank: { bankName: { 'receita': X, 'despesa': Y } }
  Map<String, Map<String, double>> _bankFlows = {};
  // Per User+Bank: { 'UserName - BankName': { 'receita': X, 'despesa': Y } }
  Map<String, Map<String, double>> _userBankFlows = {};

  // Interaction State
  int _touchedIndexPie = -1;
  String? _selectedBankDetail;
  String? _selectedUserBankDetail;

  @override
  void initState() {
    super.initState();
    _initMonths();
  }

  void _initMonths() {
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final str = DateFormat('MM/yyyy').format(d);
      _availableMonths.add(str);
    }
    _selectedMonth = _availableMonths.first;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = SupabaseHelper.instance.client;

      final parts = _selectedMonth.split('/');
      final start = DateTime(int.parse(parts[1]), int.parse(parts[0]), 1).toIso8601String();
      final end = DateTime(int.parse(parts[1]), int.parse(parts[0]) + 1, 1).toIso8601String();

      final allTransRaw = await supabase
          .from('transacoes')
          .select('*, categorias(nome, cor_hexadecimal), contas_bancarias(nome), metodos_pagamento(nome), usuarios(nome)')
          .filter('deleted_at', 'is', null);

      final allTrans = allTransRaw.map((r) => <String, dynamic>{
        ...r,
        'CategoriaNome': r['categorias']?['nome'] ?? 'Sem Categoria',
        'Cor_Hexadecimal': r['categorias']?['cor_hexadecimal'] ?? '#9E9E9E',
        'BancoNome': r['contas_bancarias']?['nome'] ?? 'Sem Conta',
        'MetodoNome': r['metodos_pagamento']?['nome'] ?? 'Sem Método',
        'UsuarioNome': r['usuarios']?['nome'] ?? 'Sem Usuário',
        'Data': r['data'],
        'Valor': r['valor'],
        'ID': r['id'],
        'Tipo': r['tipo'],
        'Paga': r['paga'],
      }).toList();

      final startDt = DateTime.parse(start);
      final endDt = DateTime.parse(end);

      // Filter paid transactions within the selected month
      List<Map<String, dynamic>> monthTransactions = [];
      List<Map<String, dynamic>> expenses = [];
      List<String> expenseIds = [];

      for (var t in allTrans) {
        if (t['Paga'] != 1) continue;
        final dataStr = t['Data']?.toString() ?? '';
        if (dataStr.isEmpty) continue;
        
        try {
          final d = DateTime.parse(dataStr);
          if ((d.isAfter(startDt) || d.isAtSameMomentAs(startDt)) && d.isBefore(endDt)) {
            monthTransactions.add(t);
            if (t['Tipo'] == 'Despesa') {
              expenses.add(t);
              expenseIds.add(t['ID'].toString());
            }
          }
        } catch (_) {}
      }

      // Fetch items for expense transactions
      final allItemsRaw = await supabase.from('lista_compras').select().filter('deleted_at', 'is', null);
      final allItems = allItemsRaw.map((r) => <String, dynamic>{
        ...r,
        'Transacao_ID': r['transacao_id'],
        'Preco': r['preco'],
        'Quantidade': r['quantidade'],
        'CategoriaNome': r['categoria_nome'],
        'Cor_Hexadecimal': r['cor_hexadecimal'],
      }).toList();

      Map<String, List<Map<String, dynamic>>> itemsByTrans = {};
      for (var item in allItems) {
        final tId = item['Transacao_ID'].toString();
        if (expenseIds.contains(tId)) {
          if (!itemsByTrans.containsKey(tId)) itemsByTrans[tId] = [];
          itemsByTrans[tId]!.add(item);
        }
      }

      // Category totals (expenses only)
      Map<String, double> catTotals = {};
      Map<String, String> catColors = {};
      double grandTotal = 0;

      for (var exp in expenses) {
        final tId = exp['ID'].toString();
        double valor = ((exp['Valor'] as num?) ?? 0).toDouble();
        grandTotal += valor;

        if (itemsByTrans.containsKey(tId)) {
          double itemsSum = 0;
          for (var item in itemsByTrans[tId]!) {
            double preco = (item['Preco'] as num?)?.toDouble() ?? 0;
            double qtde = (item['Quantidade'] as num?)?.toDouble() ?? 1;
            double itemTotal = preco * qtde;
            itemsSum += itemTotal;

            String catName = (item['CategoriaNome'] as String?) ?? (exp['CategoriaNome'] as String? ?? 'Sem Categoria');
            String catColor = (item['Cor_Hexadecimal'] as String?) ?? (exp['Cor_Hexadecimal'] as String? ?? '#9E9E9E');

            catTotals[catName] = (catTotals[catName] ?? 0) + itemTotal;
            catColors[catName] = catColor;
          }

          double remainder = valor - itemsSum;
          if (remainder > 0.01) {
            String catName = exp['CategoriaNome'] as String? ?? 'Sem Categoria';
            String catColor = exp['Cor_Hexadecimal'] as String? ?? '#9E9E9E';
            catTotals[catName] = (catTotals[catName] ?? 0) + remainder;
            catColors[catName] = catColor;
          }
        } else {
          String catName = exp['CategoriaNome'] as String? ?? 'Sem Categoria';
          String catColor = exp['Cor_Hexadecimal'] as String? ?? '#9E9E9E';
          catTotals[catName] = (catTotals[catName] ?? 0) + valor;
          catColors[catName] = catColor;
        }
      }

      // --- NEW: Build bank flows (receita vs despesa per bank) ---
      Map<String, Map<String, double>> bankFlows = {};
      Map<String, Map<String, double>> userBankFlows = {};

      for (var t in monthTransactions) {
        final bankName = t['BancoNome'] as String? ?? 'Sem Conta';
        final userName = t['UsuarioNome'] as String? ?? 'Sem Usuário';
        final tipo = t['Tipo'] as String? ?? '';
        double valor = ((t['Valor'] as num?) ?? 0).toDouble();

        // Per bank
        bankFlows.putIfAbsent(bankName, () => {'receita': 0.0, 'despesa': 0.0});
        if (tipo == 'Receita') {
          bankFlows[bankName]!['receita'] = (bankFlows[bankName]!['receita'] ?? 0) + valor;
        } else if (tipo == 'Despesa') {
          bankFlows[bankName]!['despesa'] = (bankFlows[bankName]!['despesa'] ?? 0) + valor;
        }

        // Per user + bank
        final userBankKey = '$userName\n$bankName';
        userBankFlows.putIfAbsent(userBankKey, () => {'receita': 0.0, 'despesa': 0.0});
        if (tipo == 'Receita') {
          userBankFlows[userBankKey]!['receita'] = (userBankFlows[userBankKey]!['receita'] ?? 0) + valor;
        } else if (tipo == 'Despesa') {
          userBankFlows[userBankKey]!['despesa'] = (userBankFlows[userBankKey]!['despesa'] ?? 0) + valor;
        }
      }

      if (mounted) {
        setState(() {
          _categoryTotals = catTotals;
          _categoryColors = catColors;
          _totalExpenses = grandTotal;
          _bankFlows = bankFlows;
          _userBankFlows = userBankFlows;
          _isLoading = false;
          _touchedIndexPie = -1;
          _selectedBankDetail = null;
          _selectedUserBankDetail = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar relatórios: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildDonutChart() {
    if (_categoryTotals.isEmpty) return const SizedBox.shrink();

    final List<MapEntry<String, double>> sortedData = _categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final List<PieChartSectionData> sections = [];
    int idx = 0;

    for (var entry in sortedData) {
      final isTouched = idx == _touchedIndexPie;
      final radius = isTouched ? 45.0 : 35.0;

      Color c;
      if (_categoryColors.containsKey(entry.key)) {
        c = Color(int.parse(_categoryColors[entry.key]!.replaceAll('#', '0xFF')));
      } else {
        c = Colors.grey;
      }

      sections.add(
        PieChartSectionData(
          color: c,
          value: entry.value,
          title: '',
          radius: radius,
          borderSide: isTouched ? BorderSide(color: Colors.white.withOpacity(0.9), width: 3) : BorderSide.none,
          badgeWidget: isTouched
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                  child: Text('${((entry.value / _totalExpenses) * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              : null,
          badgePositionPercentageOffset: 1.15,
        ),
      );
      idx++;
    }

    final isSliceTouched = _touchedIndexPie >= 0 && _touchedIndexPie < sortedData.length;
    final touchedEntry = isSliceTouched ? sortedData[_touchedIndexPie] : null;
    final touchedColor = touchedEntry != null && _categoryColors.containsKey(touchedEntry.key)
        ? Color(int.parse(_categoryColors[touchedEntry.key]!.replaceAll('#', '0xFF')))
        : null;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E2235) : Colors.white,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Despesas por Categoria',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isSliceTouched)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _touchedIndexPie = -1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 14, color: AppColors.iconMuted(context)),
                          const SizedBox(width: 2),
                          Text('Limpar', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context))),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    'Toque para ver',
                    style: TextStyle(fontSize: 11, color: AppColors.mutedText(context)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                            return;
                          }
                          setState(() {
                            _touchedIndexPie = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sectionsSpace: 2,
                      centerSpaceRadius: 75,
                      sections: sections,
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 500),
                    swapAnimationCurve: Curves.easeInOutCubic,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSliceTouched && touchedEntry != null) ...[
                          Text(
                            touchedEntry.key,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: touchedColor ?? AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(touchedEntry.value),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '${((touchedEntry.value / _totalExpenses) * 100).toStringAsFixed(1)}% do total',
                            style: TextStyle(fontSize: 11, color: AppColors.mutedText(context), fontWeight: FontWeight.w600),
                          ),
                        ] else ...[
                          Text('Total do Mês', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context))),
                          const SizedBox(height: 4),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: _totalExpenses),
                            duration: const Duration(seconds: 1),
                            builder: (context, value, child) {
                              return Text(
                                CurrencyFormatter.format(value),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a stacked bar chart with green (receita) on bottom and red (despesa) on top
  Widget _buildStackedFlowChart(String title, Map<String, Map<String, double>> flowData, {required bool isUserBank, String? selectedDetail, required ValueChanged<String?> onSelect}) {
    if (flowData.isEmpty) return const SizedBox.shrink();

    final entries = flowData.entries.toList();
    // Sort by total volume descending
    entries.sort((a, b) {
      final totalA = (a.value['receita'] ?? 0) + (a.value['despesa'] ?? 0);
      final totalB = (b.value['receita'] ?? 0) + (b.value['despesa'] ?? 0);
      return totalB.compareTo(totalA);
    });

    double maxVal = 0;
    for (var e in entries) {
      final total = (e.value['receita'] ?? 0) + (e.value['despesa'] ?? 0);
      if (total > maxVal) maxVal = total;
    }
    if (maxVal == 0) maxVal = 1;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E2235) : Colors.white,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Legend
            Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green.shade400, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text('Receita', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context))),
                const SizedBox(width: 16),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text('Despesa', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context))),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      if (event.isInterestedForInteractions && barTouchResponse?.spot != null) {
                        final idx = barTouchResponse!.spot!.touchedBarGroupIndex;
                        if (idx >= 0 && idx < entries.length) {
                          setState(() {
                            onSelect(entries[idx].key);
                          });
                        }
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.transparent,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) => null,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: isUserBank ? 50 : 40,
                        getTitlesWidget: (value, meta) {
                          if (value >= 0 && value < entries.length) {
                            String name = entries[value.toInt()].key;
                            if (isUserBank) {
                              // Format "User\nBank" for display
                              final parts = name.split('\n');
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(parts[0].length > 8 ? '${parts[0].substring(0, 8)}.' : parts[0],
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                                    Text(parts.length > 1 ? (parts[1].length > 8 ? '${parts[1].substring(0, 8)}.' : parts[1]) : '',
                                        style: TextStyle(fontSize: 8, color: AppColors.mutedText(context))),
                                  ],
                                ),
                              );
                            } else {
                              if (name.length > 10) name = '${name.substring(0, 10)}..';
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                              );
                            }
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: AppColors.divider(context), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final rec = entry.value.value['receita'] ?? 0.0;
                    final desp = entry.value.value['despesa'] ?? 0.0;
                    final isSelected = selectedDetail == entry.value.key;
                    final barWidth = isSelected ? 30.0 : 22.0;

                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: rec + desp,
                          width: barWidth,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          rodStackItems: [
                            // Green (receita) on bottom
                            BarChartRodStackItem(0, rec, Colors.green.shade400),
                            // Red (despesa) on top
                            BarChartRodStackItem(rec, rec + desp, Colors.red.shade400),
                          ],
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxVal * 1.2,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.03)
                                : Colors.black.withOpacity(0.03),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                swapAnimationDuration: const Duration(milliseconds: 500),
                swapAnimationCurve: Curves.easeInOut,
              ),
            ),
            // Detail text when a column is selected
            if (selectedDetail != null && flowData.containsKey(selectedDetail))
              _buildFlowDetailCard(selectedDetail!, flowData[selectedDetail]!, isUserBank),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowDetailCard(String key, Map<String, double> values, bool isUserBank) {
    final rec = values['receita'] ?? 0.0;
    final desp = values['despesa'] ?? 0.0;
    final saldo = rec - desp;
    final total = rec + desp;
    final recPct = total > 0 ? (rec / total * 100) : 0.0;
    final despPct = total > 0 ? (desp / total * 100) : 0.0;

    String displayName = key;
    if (isUserBank) {
      displayName = key.replaceAll('\n', ' — ');
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900.withOpacity(0.15),
            Colors.red.shade900.withOpacity(0.15),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Icon(Icons.arrow_downward, color: Colors.green.shade400, size: 20),
                    const SizedBox(height: 4),
                    Text('Entrada', style: TextStyle(fontSize: 11, color: AppColors.secondaryText(context))),
                    const SizedBox(height: 2),
                    Text(CurrencyFormatter.format(rec),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade400)),
                    Text('${recPct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: AppColors.secondaryText(context))),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: AppColors.divider(context),
              ),
              Expanded(
                child: Column(
                  children: [
                    Icon(Icons.arrow_upward, color: Colors.red.shade400, size: 20),
                    const SizedBox(height: 4),
                    Text('Saída', style: TextStyle(fontSize: 11, color: AppColors.secondaryText(context))),
                    const SizedBox(height: 2),
                    Text(CurrencyFormatter.format(desp),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red.shade400)),
                    Text('${despPct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: AppColors.secondaryText(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Saldo: ', style: TextStyle(fontSize: 13, color: AppColors.secondaryText(context))),
              Text(
                CurrencyFormatter.format(saldo),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: saldo >= 0 ? Colors.green.shade400 : Colors.red.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios', style: TextStyle(fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              value: _selectedMonth,
              underline: const SizedBox(),
              icon: const Icon(Icons.calendar_month, color: Colors.white),
              dropdownColor: Theme.of(context).primaryColor,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              items: _availableMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMonth = val);
                  _loadData();
                }
              },
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categoryTotals.isEmpty && _bankFlows.isEmpty
              ? const Center(child: Text('Nenhuma transação neste mês.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildDonutChart(),
                      _buildStackedFlowChart(
                        'Entrada e Saída por Banco',
                        _bankFlows,
                        isUserBank: false,
                        selectedDetail: _selectedBankDetail,
                        onSelect: (val) => _selectedBankDetail = val,
                      ),
                      _buildStackedFlowChart(
                        'Entrada e Saída por Usuário e Banco',
                        _userBankFlows,
                        isUserBank: true,
                        selectedDetail: _selectedUserBankDetail,
                        onSelect: (val) => _selectedUserBankDetail = val,
                      ),
                    ],
                  ),
                ),
    );
  }
}
