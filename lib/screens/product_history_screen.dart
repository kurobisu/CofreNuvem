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
    
    _categorias = await db.query(
      DatabaseHelper.tableCategorias,
      where: 'Tipo != ? AND Oculta = 0',
      whereArgs: ['Receita'],
      orderBy: 'Nome ASC'
    );

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

  Future<void> _showPriceHistory(int productId, String productName) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT lc.Preco, t.Data 
      FROM ${DatabaseHelper.tableListaCompras} lc
      JOIN ${DatabaseHelper.tableTransacoes} t ON lc.Transacao_ID = t.ID
      JOIN ${DatabaseHelper.tableProdutos} p ON lc.Nome = p.Nome
      WHERE p.ID = ? AND lc.Transacao_ID IS NOT NULL
      ORDER BY t.Data DESC
    ''', [productId]);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Histórico: $productName'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: result.isEmpty
                ? const Center(child: Text('Nenhuma compra registrada.'))
                : ListView.builder(
                    itemCount: result.length,
                    itemBuilder: (context, index) {
                      final row = result[index];
                      final dateStr = row['Data'] as String;
                      final price = (row['Preco'] as num).toDouble();
                      final date = DateTime.parse(dateStr);
                      final formattedDate = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";

                      return ListTile(
                        leading: const Icon(Icons.shopping_cart_checkout, color: Colors.green),
                        title: Text(CurrencyFormatter.format(price), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(formattedDate),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))
          ],
        );
      },
    );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Favoritos da Casa 🏆', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: top5.length,
            itemBuilder: (context, index) {
              final p = top5[index];
              Color catColor = Colors.blueAccent;
              if (p['Cor_Hexadecimal'] != null) {
                catColor = Color(int.parse(p['Cor_Hexadecimal'].replaceAll('#', '0xFF')));
              }
              
              return Container(
                width: 140,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [catColor.withOpacity(0.8), catColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: catColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                  ]
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showPriceHistory(p['ID'] as int, p['Nome'] as String),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(Icons.star, color: Colors.white70, size: 20),
                              Text('#${index + 1}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['Nome'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${p['BuyCount']} compras', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          )
                        ],
                      ),
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
          : ListView.builder(
              itemCount: _filteredStats.isEmpty ? 2 : _filteredStats.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _searchQuery.isEmpty ? _buildTopProductsChart() : const SizedBox.shrink();
                }

                if (_filteredStats.isEmpty) {
                  return const SizedBox(
                    height: 300,
                    child: Center(child: Text('Nenhum produto cadastrado.')),
                  );
                }

                final stat = _filteredStats[index - 1];
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

                return Column(
                  children: [
                    if (index > 1) const Divider(height: 1),
                    ExpansionTile(
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
                              icon: const Icon(Icons.show_chart, color: Colors.purple),
                              tooltip: 'Ver Histórico',
                              onPressed: () => _showPriceHistory(stat['ID'] as int, stat['Nome'] as String),
                            ),
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
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
