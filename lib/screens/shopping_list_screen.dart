import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../database/supabase_helper.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import 'transaction_form_screen.dart';
import 'product_history_screen.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  Map<String, double> _productHistory = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadHistory();
  }

  Future<void> _loadItems() async {
    final db = await SupabaseHelper.instance.database;
    final result = await db.query(SupabaseHelper.tableListaCompras, where: 'Transacao_ID IS NULL', orderBy: 'Comprado ASC, ID DESC');
    setState(() {
      _items = result;
      _isLoading = false;
    });
  }

  Future<void> _loadHistory() async {
    final db = await SupabaseHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT p.Nome, lc.Preco 
      FROM ${SupabaseHelper.tableProdutos} p
      LEFT JOIN ${SupabaseHelper.tableListaCompras} lc ON p.Nome = lc.Nome AND lc.Transacao_ID IS NOT NULL
      ORDER BY lc.ID DESC
    ''');
    
    Map<String, double> history = {};
    for (var row in result) {
      final name = row['Nome'] as String;
      bool exists = history.keys.any((k) => k.toLowerCase() == name.trim().toLowerCase());
      if (!exists) {
        history[name.trim()] = row['Preco'] != null ? (row['Preco'] as num).toDouble() : 0.0;
      }
    }
    
    if (mounted) {
      setState(() {
        _productHistory = history;
      });
    }
  }

  Future<void> _addItem(String nome, double preco, double qtde) async {
    final db = await SupabaseHelper.instance.database;
    
    // Auto-create product in library if not exists
    await db.insert(SupabaseHelper.tableProdutos, {'Nome': nome.trim()}, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert(SupabaseHelper.tableListaCompras, {
      'Nome': nome.trim(),
      'Preco': preco,
      'Quantidade': qtde,
      'Comprado': 0,
    });
    _loadItems();
  }

  Future<void> _updateItem(String id, String nome, double preco, double qtde) async {
    final db = await SupabaseHelper.instance.database;
    
    // Auto-create product in library if not exists
    await db.insert(SupabaseHelper.tableProdutos, {'Nome': nome.trim()}, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.update(SupabaseHelper.tableListaCompras, {
      'Nome': nome.trim(),
      'Preco': preco,
      'Quantidade': qtde,
    }, where: 'ID = ?', whereArgs: [id]);
    _loadItems();
  }

  Future<void> _toggleItem(String id, int atual) async {
    final db = await SupabaseHelper.instance.database;
    await db.update(SupabaseHelper.tableListaCompras, {'Comprado': atual == 1 ? 0 : 1}, where: 'ID = ?', whereArgs: [id]);
    _loadItems();
  }
  
  Future<void> _deleteItem(String id) async {
    final db = await SupabaseHelper.instance.database;
    await db.delete(SupabaseHelper.tableListaCompras, where: 'ID = ?', whereArgs: [id]);
    _loadItems();
  }

  void _showItemModal({Map<String, dynamic>? itemToEdit}) {
    final nomeController = TextEditingController(text: itemToEdit?['Nome'] ?? '');
    final precoController = TextEditingController(
      text: itemToEdit != null && itemToEdit['Preco'] > 0 ? CurrencyFormatter.format(itemToEdit['Preco']) : ''
    );
    final qtdeController = TextEditingController(
      text: itemToEdit != null ? itemToEdit['Quantidade'].toString().replaceAll('.0', '') : '1'
    );
    
    double? lastPrice;
    if (itemToEdit != null) {
      lastPrice = _productHistory[itemToEdit['Nome'].toString().trim()];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            // Check inflation
            Widget inflationWidget = const SizedBox.shrink();
            final currentName = nomeController.text.trim();
            if (currentName.isNotEmpty && _productHistory.containsKey(currentName)) {
              final historicalPrice = _productHistory[currentName]!;
              final numericPreco = precoController.text.replaceAll(RegExp('[^0-9]'), '');
              final currentPrice = numericPreco.isEmpty ? 0.0 : double.parse(numericPreco) / 100;
              
              if (currentPrice > 0 && historicalPrice > 0) {
                final diff = currentPrice - historicalPrice;
                final pct = (diff / historicalPrice) * 100;
                if (diff > 0) {
                  inflationWidget = Text(
                    '+ ${CurrencyFormatter.format(diff)} (+${pct.toStringAsFixed(1)}%) vs histórico (${CurrencyFormatter.format(historicalPrice)})',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                  );
                } else if (diff < 0) {
                  inflationWidget = Text(
                    '- ${CurrencyFormatter.format(diff.abs())} (${pct.toStringAsFixed(1)}%) vs histórico (${CurrencyFormatter.format(historicalPrice)})',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                  );
                } else {
                  inflationWidget = Text(
                    'Mesmo preço do histórico (${CurrencyFormatter.format(historicalPrice)})',
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                  );
                }
              } else if (historicalPrice > 0) {
                inflationWidget = Text(
                  'Último preço: ${CurrencyFormatter.format(historicalPrice)}',
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(itemToEdit == null ? 'Novo Item' : 'Editar Item', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (itemToEdit != null)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Excluir Item',
                          onPressed: () {
                            _deleteItem(itemToEdit['ID']);
                            Navigator.pop(ctx);
                          },
                        )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: nomeController.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return _productHistory.keys.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      setModalState(() {
                        nomeController.text = selection;
                        final histPrice = _productHistory[selection];
                        if (histPrice != null && precoController.text.isEmpty) {
                          precoController.text = CurrencyFormatter.format(histPrice);
                        }
                      });
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      // Sync Autocomplete controller with our state
                      controller.addListener(() {
                        if (nomeController.text != controller.text) {
                          nomeController.text = controller.text;
                          setModalState(() {});
                        }
                      });
                      // If editing, set initial value to the inner controller as well
                      if (controller.text.isEmpty && nomeController.text.isNotEmpty) {
                        controller.text = nomeController.text;
                      }
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'Produto', border: OutlineInputBorder()),
                        textCapitalization: TextCapitalization.sentences,
                        autofocus: itemToEdit == null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: precoController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                          decoration: const InputDecoration(labelText: 'Preço (Opcional)', border: OutlineInputBorder()),
                          onChanged: (val) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: qtdeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Quantidade', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  inflationWidget,
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                    onPressed: () {
                      final nome = nomeController.text.trim();
                      if (nome.isNotEmpty) {
                        final numericPreco = precoController.text.replaceAll(RegExp('[^0-9]'), '');
                        final preco = numericPreco.isEmpty ? 0.0 : double.parse(numericPreco) / 100;
                        final qtde = double.tryParse(qtdeController.text.replaceAll(',', '.')) ?? 1.0;
                        
                        if (itemToEdit == null) {
                          _addItem(nome, preco, qtde).then((_) => _loadHistory());
                        } else {
                          _updateItem(itemToEdit['ID'], nome, preco, qtde).then((_) => _loadHistory());
                        }
                        Navigator.pop(ctx);
                      }
                    },
                    child: Text(itemToEdit == null ? 'Adicionar à Lista' : 'Salvar Alterações'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _finalizarCompra() async {
    // Sum everything that is checked
    final comprados = _items.where((i) => i['Comprado'] == 1).toList();
    if (comprados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marque pelo menos um item como comprado.')));
      return;
    }

    double total = 0;
    List<String> ids = [];
    for (var item in comprados) {
      total += (item['Preco'] as num) * (item['Quantidade'] as num);
      ids.add(item['ID'].toString());
    }

    final db = await SupabaseHelper.instance.database;
    final catList = await db.query(SupabaseHelper.tableCategorias, where: "Nome = 'Mercado'");
    String? categoriaId;
    if (catList.isEmpty) {
      categoriaId = await db.insert(SupabaseHelper.tableCategorias, {
        'Nome': 'Mercado',
        'Cor_Hexadecimal': '#4CAF50',
        'Tipo': 'Ambas',
      });
    } else {
      categoriaId = catList.first['ID'].toString();
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionFormScreen(
          initialDescricao: 'Compras Mercado',
          initialValor: total,
          initialCategoria: categoriaId,
          shoppingListItemIds: ids,
          forceDespesa: true,
        ),
      ),
    ).then((_) {
      _loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    double totalPrevisto = 0;
    double totalCarrinho = 0;
    
    for (var item in _items) {
      final val = (item['Preco'] as num) * (item['Quantidade'] as num);
      totalPrevisto += val;
      if (item['Comprado'] == 1) totalCarrinho += val;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Compras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Biblioteca de Produtos',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductHistoryScreen())).then((_) {
                _loadItems();
                _loadHistory();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_checkout),
            tooltip: 'Finalizar Compra',
            onPressed: _items.any((i) => i['Comprado'] == 1) ? _finalizarCompra : null,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Previsto', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(CurrencyFormatter.format(totalPrevisto), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('No Carrinho', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(CurrencyFormatter.format(totalCarrinho), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('Sua lista está vazia.'))
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final isComprado = item['Comprado'] == 1;
                            final totalItem = (item['Preco'] as num) * (item['Quantidade'] as num);
                            
                            return Dismissible(
                              key: Key(item['ID'].toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteItem(item['ID']),
                              child: ListTile(
                                leading: Checkbox(
                                  value: isComprado,
                                  onChanged: (_) => _toggleItem(item['ID'], item['Comprado']),
                                ),
                                title: Text(item['Nome'], style: TextStyle(decoration: isComprado ? TextDecoration.lineThrough : null)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${item['Quantidade']}x ${CurrencyFormatter.format((item['Preco'] as num).toDouble())}'),
                                    if (_productHistory.containsKey(item['Nome'].toString().trim()) && (item['Preco'] as num) > 0)
                                      Builder(builder: (ctx) {
                                        final hist = _productHistory[item['Nome'].toString().trim()]!;
                                        final curr = (item['Preco'] as num).toDouble();
                                        if (hist > 0 && curr != hist) {
                                          final diff = curr - hist;
                                          final pct = (diff / hist) * 100;
                                          final color = diff > 0 ? Colors.red : Colors.green;
                                          final sign = diff > 0 ? '+' : '';
                                          return Text(
                                            '$sign${CurrencyFormatter.format(diff)} ($sign${pct.toStringAsFixed(1)}%) vs histórico',
                                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                                          );
                                        } else if (hist > 0 && curr == hist) {
                                          return const Text('Mesmo preço do histórico', style: TextStyle(color: Colors.grey, fontSize: 11));
                                        }
                                        return const SizedBox.shrink();
                                      })
                                  ],
                                ),
                                trailing: InkWell(
                                  onTap: () => _showItemModal(itemToEdit: item),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(CurrencyFormatter.format(totalItem.toDouble()), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.edit, size: 16, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                                onTap: () => _toggleItem(item['ID'], item['Comprado']),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showItemModal,
        child: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
}
