import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

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
  Map<String, double> _methodTotals = {};
  Map<String, double> _bankTotals = {};
  double _totalExpenses = 0.0;

  // Interaction State
  int _touchedIndexPie = -1;
  int _touchedIndexBank = -1;
  int _touchedIndexMethod = -1;

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
    final db = await DatabaseHelper.instance.database;

    final parts = _selectedMonth.split('/');
    final start = DateTime(int.parse(parts[1]), int.parse(parts[0]), 1).toIso8601String();
    final end = DateTime(int.parse(parts[1]), int.parse(parts[0]) + 1, 1).toIso8601String();

    // 1. Fetch expenses
    final expenses = await db.rawQuery('''
      SELECT t.ID, t.Valor, c.Nome as CategoriaNome, c.Cor_Hexadecimal, mp.Nome as MetodoNome, cb.Nome as BancoNome
      FROM ${DatabaseHelper.tableTransacoes} t
      JOIN ${DatabaseHelper.tableCategorias} c ON t.Categoria_ID = c.ID
      JOIN ${DatabaseHelper.tableMetodosPagamento} mp ON t.Metodo_ID = mp.ID
      JOIN ${DatabaseHelper.tableContasBancarias} cb ON t.Conta_ID = cb.ID
      WHERE t.Tipo = 'Despesa' AND t.Paga = 1 AND t.Data >= ? AND t.Data < ?
    ''', [start, end]);

    // 2. Fetch items for these expenses
    final items = await db.rawQuery('''
      SELECT lc.Transacao_ID, lc.Preco, lc.Quantidade, c.Nome as CategoriaNome, c.Cor_Hexadecimal
      FROM ${DatabaseHelper.tableListaCompras} lc
      JOIN ${DatabaseHelper.tableTransacoes} t ON lc.Transacao_ID = t.ID
      LEFT JOIN ${DatabaseHelper.tableProdutos} p ON lc.Nome = p.Nome
      LEFT JOIN ${DatabaseHelper.tableCategorias} c ON p.Categoria_ID = c.ID
      WHERE t.Tipo = 'Despesa' AND t.Paga = 1 AND t.Data >= ? AND t.Data < ?
    ''', [start, end]);

    Map<int, List<Map<String, dynamic>>> itemsByTrans = {};
    for (var item in items) {
      final tId = item['Transacao_ID'] as int;
      if (!itemsByTrans.containsKey(tId)) itemsByTrans[tId] = [];
      itemsByTrans[tId]!.add(item);
    }

    Map<String, double> catTotals = {};
    Map<String, String> catColors = {};
    Map<String, double> metTotals = {};
    Map<String, double> bnkTotals = {};
    double grandTotal = 0;

    for (var exp in expenses) {
      final tId = exp['ID'] as int;
      final metName = exp['MetodoNome'] as String;
      final bnkName = exp['BancoNome'] as String;
      double valor = (exp['Valor'] as num).toDouble();
      
      grandTotal += valor;
      metTotals[metName] = (metTotals[metName] ?? 0) + valor;
      bnkTotals[bnkName] = (bnkTotals[bnkName] ?? 0) + valor;

      if (itemsByTrans.containsKey(tId)) {
        double itemsSum = 0;
        for (var item in itemsByTrans[tId]!) {
          double preco = (item['Preco'] as num?)?.toDouble() ?? 0;
          double qtde = (item['Quantidade'] as num?)?.toDouble() ?? 1;
          double itemTotal = preco * qtde;
          itemsSum += itemTotal;

          String catName = item['CategoriaNome'] as String? ?? exp['CategoriaNome'] as String;
          String catColor = item['Cor_Hexadecimal'] as String? ?? exp['Cor_Hexadecimal'] as String;
          
          catTotals[catName] = (catTotals[catName] ?? 0) + itemTotal;
          catColors[catName] = catColor;
        }
        
        double remainder = valor - itemsSum;
        if (remainder > 0.01) { 
          String catName = exp['CategoriaNome'] as String;
          String catColor = exp['Cor_Hexadecimal'] as String;
          catTotals[catName] = (catTotals[catName] ?? 0) + remainder;
          catColors[catName] = catColor;
        }
      } else {
        String catName = exp['CategoriaNome'] as String;
        String catColor = exp['Cor_Hexadecimal'] as String;
        catTotals[catName] = (catTotals[catName] ?? 0) + valor;
        catColors[catName] = catColor;
      }
    }

    setState(() {
      _categoryTotals = catTotals;
      _categoryColors = catColors;
      _methodTotals = metTotals;
      _bankTotals = bnkTotals;
      _totalExpenses = grandTotal;
      _isLoading = false;
      
      _touchedIndexPie = -1;
      _touchedIndexBank = -1;
      _touchedIndexMethod = -1;
    });
  }

  LinearGradient _getBankGradient(String bankName) {
    String name = bankName.toLowerCase();
    if (name.contains('nubank')) {
      return const LinearGradient(colors: [Color(0xFF8A05BE), Color(0xFFC040FF)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
    } else if (name.contains('itaú') || name.contains('itau')) {
      return const LinearGradient(colors: [Color(0xFFEC7000), Color(0xFFFFB200)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
    } else if (name.contains('inter')) {
      return const LinearGradient(colors: [Color(0xFFFF7A00), Color(0xFFFFB461)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
    } else if (name.contains('brasil') || name.contains('bb')) {
      return const LinearGradient(colors: [Color(0xFF0038A8), Color(0xFFFBE122)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
    } else if (name.contains('bradesco')) {
      return const LinearGradient(colors: [Color(0xFFCC092F), Color(0xFFFF4D6D)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
    } else if (name.contains('santander')) {
      return const LinearGradient(colors: [Color(0xFFEC0000), Color(0xFFFF6666)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
    } else if (name.contains('caixa')) {
      return const LinearGradient(colors: [Color(0xFF005CA9), Color(0xFFF39200)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
    }
    // Default gradient
    return const LinearGradient(colors: [Color(0xFF3F51B5), Color(0xFF00BCD4)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
  }

  LinearGradient _getMethodGradient(String methodName) {
    String name = methodName.toLowerCase();
    if (name.contains('crédito') || name.contains('credito')) {
      return const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF0072FF)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
    } else if (name.contains('débito') || name.contains('debito')) {
      return const LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
    } else if (name.contains('pix')) {
      return const LinearGradient(colors: [Color(0xFF32BFA4), Color(0xFF90F7EC)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
    } else if (name.contains('dinheiro')) {
      return const LinearGradient(colors: [Color(0xFF56AB2F), Color(0xFFA8E063)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
    }
    return const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], begin: Alignment.bottomCenter, end: Alignment.topCenter);
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
          title: '', // Text in legend instead
          radius: radius,
          borderSide: isTouched ? BorderSide(color: Colors.white.withOpacity(0.8), width: 3) : BorderSide.none,
          badgeWidget: isTouched 
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                child: Text('${((entry.value / _totalExpenses) * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            : null,
          badgePositionPercentageOffset: 1.1,
        )
      );
      idx++;
    }

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
            const Text('Despesas por Sub-categoria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                              _touchedIndexPie = -1;
                              return;
                            }
                            _touchedIndexPie = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sectionsSpace: 2,
                      centerSpaceRadius: 70, // Donut hole
                      sections: sections,
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 600),
                    swapAnimationCurve: Curves.easeInOutBack,
                  ),
                  // Center Text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Total do Mês', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: sortedData.asMap().entries.map((e) {
                int i = e.key;
                String catName = e.value.key;
                double val = e.value.value;
                Color c = Color(int.parse(_categoryColors[catName]!.replaceAll('#', '0xFF')));
                bool isTouched = i == _touchedIndexPie;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isTouched ? c.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isTouched ? c : Colors.transparent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(catName, style: TextStyle(fontWeight: isTouched ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                          Text(CurrencyFormatter.format(val), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                        ],
                      )
                    ],
                  ),
                );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBeautifulBarChart(String title, Map<String, double> data, bool isBank) {
    if (data.isEmpty) return const SizedBox.shrink();

    final List<MapEntry<String, double>> sortedData = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final double maxVal = sortedData.first.value;
    final touchedIndex = isBank ? _touchedIndexBank : _touchedIndexMethod;

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
            const SizedBox(height: 32),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.3, // extra space for tooltips
                  barTouchData: BarTouchData(
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions || barTouchResponse == null || barTouchResponse.spot == null) {
                          if (isBank) _touchedIndexBank = -1;
                          else _touchedIndexMethod = -1;
                          return;
                        }
                        if (isBank) _touchedIndexBank = barTouchResponse.spot!.touchedBarGroupIndex;
                        else _touchedIndexMethod = barTouchResponse.spot!.touchedBarGroupIndex;
                      });
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${sortedData[group.x.toInt()].key}\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          children: [
                            TextSpan(
                              text: CurrencyFormatter.format(rod.toY),
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 14),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value >= 0 && value < sortedData.length) {
                            String name = sortedData[value.toInt()].key;
                            if (name.length > 10) name = '${name.substring(0, 10)}...';
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                            );
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
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: sortedData.asMap().entries.map((entry) {
                    final isTouched = entry.key == touchedIndex;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value,
                          gradient: isBank ? _getBankGradient(entry.value.key) : _getMethodGradient(entry.value.key),
                          width: isTouched ? 28 : 22, // Fatter on touch
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxVal * 1.3,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          ),
                        )
                      ],
                    );
                  }).toList(),
                ),
                swapAnimationDuration: const Duration(milliseconds: 600),
                swapAnimationCurve: Curves.easeInOut,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios Avançados'),
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
          : _categoryTotals.isEmpty
              ? const Center(child: Text('Nenhuma despesa neste mês.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildDonutChart(),
                      _buildBeautifulBarChart('Bancos Mais Utilizados', _bankTotals, true),
                      _buildBeautifulBarChart('Métodos de Pagamento', _methodTotals, false),
                    ],
                  ),
                ),
    );
  }
}
