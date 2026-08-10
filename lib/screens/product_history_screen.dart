import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database_helper.dart';
import '../utils/currency_formatter.dart';
import '../theme/app_theme.dart';

class ProductHistoryScreen extends StatefulWidget {
  const ProductHistoryScreen({super.key});

  @override
  State<ProductHistoryScreen> createState() => _ProductHistoryScreenState();
}

class _ProductHistoryScreenState extends State<ProductHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _productStats = [];
  List<Map<String, dynamic>> _filteredStats = [];
  List<Map<String, dynamic>> _categorias = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = await DatabaseHelper.instance.database;
    
    _categorias = await db.query(DatabaseHelper.tableCategorias);

    // Get all products and their history
    final result = await db.rawQuery('''
      SELECT p.ID as ProdutoID, p.Nome as ProdutoNome, p.Categoria_ID, c.Nome as CategoriaNome, c.Cor_Hexadecimal, lc.Preco, t.Data 
      FROM ${DatabaseHelper.tableProdutos} p
      LEFT JOIN ${DatabaseHelper.tableCategorias} c ON p.Categoria_ID = c.ID
      LEFT JOIN ${DatabaseHelper.tableListaCompras} lc ON p.Nome = lc.Nome AND lc.Transacao_ID IS NOT NULL
      LEFT JOIN ${DatabaseHelper.tableTransacoes} t ON lc.Transacao_ID = t.ID
      ORDER BY p.Nome ASC, t.Data ASC
    ''');

    Map<int, Map<String, dynamic>> productsMap = {};

    for (var row in result) {
      int pId = row['ProdutoID'] as int;
      
      if (!productsMap.containsKey(pId)) {
        productsMap[pId] = {
          'ID': pId,
          'Nome': row['ProdutoNome'],
          'Categoria_ID': row['Categoria_ID'],
          'CategoriaNome': row['CategoriaNome'],
          'Cor_Hexadecimal': row['Cor_Hexadecimal'],
          'Prices': <double>[],
          'BuyCount': 0,
        };
      }
      
      if (row['Preco'] != null) {
        productsMap[pId]!['Prices'].add((row['Preco'] as num).toDouble());
        productsMap[pId]!['BuyCount'] = (productsMap[pId]!['BuyCount'] as int) + 1;
      }
    }

    List<Map<String, dynamic>> stats = [];
    productsMap.forEach((id, data) {
      List<double> prices = data['Prices'];
      
      double currentPrice = 0;
      double maxPrice = 0;
      double minPrice = 0;
      double previousPrice = 0;
      
      if (prices.isNotEmpty) {
        currentPrice = prices.last;
        maxPrice = prices.reduce((curr, next) => curr > next ? curr : next);
        minPrice = prices.reduce((curr, next) => curr < next ? curr : next);
        previousPrice = prices.length > 1 ? prices[prices.length - 2] : currentPrice;
      }

      stats.add({
        'ID': data['ID'],
        'Nome': data['Nome'],
        'CategoriaNome': data['CategoriaNome'],
        'Cor_Hexadecimal': data['Cor_Hexadecimal'],
        'Categoria_ID': data['Categoria_ID'],
        'CurrentPrice': currentPrice,
        'MaxPrice': maxPrice,
        'MinPrice': minPrice,
        'PreviousPrice': previousPrice,
        'HistoryCount': prices.length,
        'BuyCount': data['BuyCount'],
      });
    });

    stats.sort((a, b) => a['Nome'].toString().toLowerCase().compareTo(b['Nome'].toString().toLowerCase()));

    setState(() {
      _productStats = stats;
      _filteredStats = stats;
      _isLoading = false;
    });
  }

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query;
      _filteredStats = _productStats.where((p) {
        return p['Nome'].toString().toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _deleteProduct(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Produto'),
        content: const Text('Tem certeza que deseja excluir este produto? Esta ação é irreversível.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Excluir')
          ),
        ],
      )
    );

    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete(DatabaseHelper.tableProdutos, where: 'ID = ?', whereArgs: [id]);
      _loadHistory();
    }
  }

  Future<void> _showProductDialog([Map<String, dynamic>? product]) async {
    final nomeController = TextEditingController(text: product?['Nome'] ?? '');
    int? selectedCategoria = product?['Categoria_ID'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(product == null ? 'Novo Produto' : 'Editar Produto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome do Produto'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedCategoria,
                decoration: const InputDecoration(labelText: 'Sub-categoria'),
                items: _categorias.map((c) => DropdownMenuItem<int>(
                  value: c['ID'] as int,
                  child: Row(
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: Color(int.parse((c['Cor_Hexadecimal'] as String).replaceAll('#', '0xFF'))),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(c['Nome'] as String),
                    ],
                  ),
                )).toList(),
                onChanged: (val) => setStateDialog(() => selectedCategoria = val),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final nome = nomeController.text.trim();
                if (nome.isNotEmpty) {
                  final db = await DatabaseHelper.instance.database;
                  if (product == null) {
                    await db.insert(DatabaseHelper.tableProdutos, {
                      'Nome': nome,
                      'Categoria_ID': selectedCategoria,
                    });
                  } else {
                    await db.update(DatabaseHelper.tableProdutos, {
                      'Nome': nome,
                      'Categoria_ID': selectedCategoria,
                    }, where: 'ID = ?', whereArgs: [product['ID']]);
                  }
                  if (mounted) Navigator.pop(context);
                  _loadHistory();
                }
              },
              child: const Text('Salvar'),
            )
          ],
        )
      )
    );
  }

  Widget _buildTopProductsChart() {
    List<Map<String, dynamic>> sortedByBuy = List.from(_productStats);
    sortedByBuy.sort((a, b) => (b['BuyCount'] as int).compareTo(a['BuyCount'] as int));
    final top5 = sortedByBuy.take(5).where((p) => p['BuyCount'] > 0).toList();

    if (top5.isEmpty) return const SizedBox.shrink();

    double maxVal = top5.isNotEmpty ? (top5.first['BuyCount'] as int).toDouble() : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top 5 Produtos Mais Comprados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal + 1,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value >= 0 && value < top5.length) {
                          String title = top5[value.toInt()]['Nome'];
                          if (title.length > 8) title = '${title.substring(0, 8)}...';
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(title, style: const TextStyle(fontSize: 10)),
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
                barGroups: top5.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var p = entry.value;
                  Color barColor = Colors.blueAccent;
                  if (p['Cor_Hexadecimal'] != null) {
                    barColor = Color(int.parse(p['Cor_Hexadecimal'].replaceAll('#', '0xFF')));
                  }
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: (p['BuyCount'] as int).toDouble(),
                        color: barColor,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal + 1,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                        ),
                      )
                    ],
                    showingTooltipIndicators: [0],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de Produtos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar produto...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _filterProducts,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_searchQuery.isEmpty) _buildTopProductsChart(),
                Expanded(
                  child: _filteredStats.isEmpty
                      ? const Center(child: Text('Nenhum produto cadastrado.'))
                      : ListView.separated(
                          itemCount: _filteredStats.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final stat = _filteredStats[index];
                            final currentPrice = stat['CurrentPrice'] as double;
                            final previousPrice = stat['PreviousPrice'] as double;
                            
                            Widget variationWidget = const SizedBox.shrink();
                            if (currentPrice > previousPrice && previousPrice > 0) {
                              final diff = currentPrice - previousPrice;
                              final pct = (diff / previousPrice) * 100;
                              variationWidget = Text('+${pct.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold));
                            } else if (currentPrice < previousPrice && previousPrice > 0) {
                              final diff = previousPrice - currentPrice;
                              final pct = (diff / previousPrice) * 100;
                              variationWidget = Text('-${pct.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold));
                            } else if (stat['HistoryCount'] > 1) {
                              variationWidget = const Text('Estável', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold));
                            }

                            Color catColor = Colors.grey;
                            if (stat['Cor_Hexadecimal'] != null) {
                              catColor = Color(int.parse((stat['Cor_Hexadecimal'] as String).replaceAll('#', '0xFF')));
                            }

                            return ExpansionTile(
                              leading: CircleAvatar(backgroundColor: catColor, child: const Icon(Icons.shopping_bag, color: Colors.white, size: 20)),
                              title: Text(stat['Nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: stat['CategoriaNome'] != null ? Text(stat['CategoriaNome'], style: TextStyle(color: catColor, fontSize: 12)) : null,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (stat['HistoryCount'] > 0) Text(CurrencyFormatter.format(currentPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (stat['HistoryCount'] == 0) const Text('S/ Histórico', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  variationWidget,
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Column(
                                        children: [
                                          const Text('Menor Preço', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text(stat['HistoryCount'] > 0 ? CurrencyFormatter.format(stat['MinPrice'] as double) : '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          const Text('Maior Preço', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text(stat['HistoryCount'] > 0 ? CurrencyFormatter.format(stat['MaxPrice'] as double) : '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showProductDialog(stat),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteProduct(stat['ID'] as int),
                                    ),
                                  ],
                                )
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
