import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/currency_formatter.dart';

class ProductHistoryScreen extends StatefulWidget {
  const ProductHistoryScreen({super.key});

  @override
  State<ProductHistoryScreen> createState() => _ProductHistoryScreenState();
}

class _ProductHistoryScreenState extends State<ProductHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _productStats = [];
  List<Map<String, dynamic>> _filteredStats = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = await DatabaseHelper.instance.database;
    // We join with Transacoes to get the Date if we wanted, but for now ID DESC is enough
    final result = await db.rawQuery('''
      SELECT lc.Nome, lc.Preco, t.Data 
      FROM ${DatabaseHelper.tableListaCompras} lc
      JOIN ${DatabaseHelper.tableTransacoes} t ON lc.Transacao_ID = t.ID
      WHERE lc.Transacao_ID IS NOT NULL
      ORDER BY t.Data ASC, lc.ID ASC
    ''');

    // Process in Dart
    Map<String, List<double>> historyMap = {};
    for (var row in result) {
      final name = row['Nome'] as String;
      final key = name.trim();
      final price = (row['Preco'] as num).toDouble();
      
      if (!historyMap.containsKey(key)) {
        historyMap[key] = [];
      }
      historyMap[key]!.add(price);
    }

    List<Map<String, dynamic>> stats = [];
    historyMap.forEach((name, prices) {
      if (prices.isNotEmpty) {
        final currentPrice = prices.last;
        final maxPrice = prices.reduce((curr, next) => curr > next ? curr : next);
        final minPrice = prices.reduce((curr, next) => curr < next ? curr : next);
        final previousPrice = prices.length > 1 ? prices[prices.length - 2] : currentPrice;
        
        stats.add({
          'Nome': name,
          'CurrentPrice': currentPrice,
          'MaxPrice': maxPrice,
          'MinPrice': minPrice,
          'PreviousPrice': previousPrice,
          'HistoryCount': prices.length,
        });
      }
    });

    // Sort alphabetically
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
          : _filteredStats.isEmpty
              ? const Center(child: Text('Nenhum histórico encontrado.'))
              : ListView.separated(
                  itemCount: _filteredStats.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final stat = _filteredStats[index];
                    final currentPrice = stat['CurrentPrice'] as double;
                    final previousPrice = stat['PreviousPrice'] as double;
                    
                    Widget variationWidget = const SizedBox.shrink();
                    if (currentPrice > previousPrice) {
                      final diff = currentPrice - previousPrice;
                      final pct = (diff / previousPrice) * 100;
                      variationWidget = Text('+${pct.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold));
                    } else if (currentPrice < previousPrice) {
                      final diff = previousPrice - currentPrice;
                      final pct = (diff / previousPrice) * 100;
                      variationWidget = Text('-${pct.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold));
                    } else if (stat['HistoryCount'] > 1) {
                      variationWidget = const Text('Estável', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold));
                    }

                    return ExpansionTile(
                      leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.shopping_bag, color: Colors.white, size: 20)),
                      title: Text(stat['Nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Último: ${CurrencyFormatter.format(currentPrice)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${stat['HistoryCount']} compras', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          variationWidget,
                        ],
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Theme.of(context).cardColor.withOpacity(0.5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('Menor Preço', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(CurrencyFormatter.format(stat['MinPrice']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text('Maior Preço', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(CurrencyFormatter.format(stat['MaxPrice']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    );
                  },
                ),
    );
  }
}
