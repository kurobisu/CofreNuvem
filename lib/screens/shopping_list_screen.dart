import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import 'transaction_form_screen.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(DatabaseHelper.tableListaCompras, orderBy: 'Comprado ASC, ID DESC');
    setState(() {
      _items = result;
      _isLoading = false;
    });
  }

  Future<void> _addItem(String nome, double preco, double qtde) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(DatabaseHelper.tableListaCompras, {
      'Nome': nome,
      'Preco': preco,
      'Quantidade': qtde,
      'Comprado': 0,
    });
    _loadItems();
  }

  Future<void> _toggleItem(int id, int atual) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(DatabaseHelper.tableListaCompras, {'Comprado': atual == 1 ? 0 : 1}, where: 'ID = ?', whereArgs: [id]);
    _loadItems();
  }
  
  Future<void> _deleteItem(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableListaCompras, where: 'ID = ?', whereArgs: [id]);
    _loadItems();
  }

  Future<void> _clearComprados() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableListaCompras, where: 'Comprado = 1');
    _loadItems();
  }

  void _showAddItemModal() {
    final nomeController = TextEditingController();
    final precoController = TextEditingController();
    final qtdeController = TextEditingController(text: '1');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Novo Item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Produto', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
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
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                onPressed: () {
                  final nome = nomeController.text.trim();
                  if (nome.isNotEmpty) {
                    final numericPreco = precoController.text.replaceAll(RegExp('[^0-9]'), '');
                    final preco = numericPreco.isEmpty ? 0.0 : double.parse(numericPreco) / 100;
                    final qtde = double.tryParse(qtdeController.text.replaceAll(',', '.')) ?? 1.0;
                    
                    _addItem(nome, preco, qtde);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Adicionar à Lista'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  void _finalizarCompra() {
    // Sum everything that is checked
    final comprados = _items.where((i) => i['Comprado'] == 1).toList();
    if (comprados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marque pelo menos um item como comprado.')));
      return;
    }

    double total = 0;
    for (var item in comprados) {
      total += (item['Preco'] as num) * (item['Quantidade'] as num);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionFormScreen(
          initialDescricao: 'Compras Mercado',
          initialValor: total,
        ),
      ),
    ).then((_) {
      // Optional: Ask to clear checked items
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Compra Finalizada'),
          content: const Text('Deseja limpar os itens comprados da lista?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Manter na Lista')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _clearComprados();
              }, 
              child: const Text('Limpar Comprados', style: TextStyle(color: Colors.red))
            ),
          ],
        )
      );
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
                                subtitle: Text('${item['Quantidade']}x ${CurrencyFormatter.format((item['Preco'] as num).toDouble())}'),
                                trailing: Text(CurrencyFormatter.format(totalItem.toDouble()), style: const TextStyle(fontWeight: FontWeight.w600)),
                                onTap: () => _toggleItem(item['ID'], item['Comprado']),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemModal,
        child: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
}
