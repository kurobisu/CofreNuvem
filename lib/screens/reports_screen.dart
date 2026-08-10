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

    for (var exp in expenses) {
      final tId = exp['ID'] as int;
      final metName = exp['MetodoNome'] as String;
      final bnkName = exp['BancoNome'] as String;
      double valor = (exp['Valor'] as num).toDouble();

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
        
        // Remainder goes to parent category
        double remainder = valor - itemsSum;
        if (remainder > 0.01) { // Floating point tolerance
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
      _isLoading = false;
    });
  }

  Widget _buildPieChart(String title, Map<String, double> data, [Map<String, String>? colors]) {
    if (data.isEmpty) return const SizedBox.shrink();

    final List<PieChartSectionData> sections = [];
    final List<MapEntry<String, double>> sortedData = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    int colorIdx = 0;
    final fallbackColors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];

    for (var entry in sortedData) {
      Color c;
      if (colors != null && colors.containsKey(entry.key)) {
        c = Color(int.parse(colors[entry.key]!.replaceAll('#', '0xFF')));
      } else {
        c = fallbackColors[colorIdx % fallbackColors.length];
        colorIdx++;
      }

      sections.add(
        PieChartSectionData(
          color: c,
          value: entry.value,
          title: '', // Hide text on chart, use legend
          radius: 40,
        )
      );
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 150,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: sections,
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 800),
                      swapAnimationCurve: Curves.easeInOut,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sortedData.take(6).map((e) {
                      Color c;
                      if (colors != null && colors.containsKey(e.key)) {
                        c = Color(int.parse(colors[e.key]!.replaceAll('#', '0xFF')));
                      } else {
                        c = sections.firstWhere((s) => s.value == e.value).color;
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                            Text(CurrencyFormatter.format(e.value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(String title, Map<String, double> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final List<MapEntry<String, double>> sortedData = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final double maxVal = sortedData.first.value;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${sortedData[group.x.toInt()].key}\n${CurrencyFormatter.format(rod.toY)}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value >= 0 && value < sortedData.length) {
                            String name = sortedData[value.toInt()].key;
                            if (name.length > 8) name = '${name.substring(0, 8)}...';
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(name, style: const TextStyle(fontSize: 10)),
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
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: sortedData.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value,
                          color: AppTheme.accent,
                          width: 24,
                          borderRadius: BorderRadius.circular(4),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxVal * 1.2,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                          ),
                        )
                      ],
                    );
                  }).toList(),
                ),
                swapAnimationDuration: const Duration(milliseconds: 800),
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
                  child: Column(
                    children: [
                      _buildPieChart('Despesas Detalhadas (Sub-categorias)', _categoryTotals, _categoryColors),
                      _buildBarChart('Bancos Mais Utilizados', _bankTotals),
                      _buildBarChart('Métodos de Pagamento', _methodTotals),
                    ],
                  ),
                ),
    );
  }
}
