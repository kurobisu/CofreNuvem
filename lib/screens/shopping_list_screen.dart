import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/supabase_helper.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/app_colors.dart';

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
    try {
      final db = await SupabaseHelper.instance.database;
      final result = await db.query(SupabaseHelper.tableListaCompras, where: 'Transacao_ID IS NULL', orderBy: 'Comprado ASC, ID DESC');
      final filteredResult = result.where((item) {
        final nome = (item['nome'] ?? item['Nome'] ?? '').toString();
        final comprado = item['comprado'] ?? item['Comprado'];
        return !nome.startsWith('prod_cat:') && comprado != -1 && comprado != 2;
      }).toList();
      if (mounted) {
        setState(() {
          _items = filteredResult;
        });
      }
    } catch (e) {
      debugPrint('Erro _loadItems: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    try {
      final supabase = SupabaseHelper.instance.client;
      final listaComprasRaw = await supabase.from('lista_compras')
          .select('nome, preco')
          .filter('deleted_at', 'is', null)
          .order('id', ascending: false);
      
      Map<String, double> history = {};
      for (var lcRaw in listaComprasRaw) {
        final lc = CaseInsensitiveMap(lcRaw as Map<String, dynamic>);
        String name = (lc['nome'] ?? '').toString().trim();
        if (name.isNotEmpty && !name.startsWith('prod_cat:')) {
          double price = ((lc['preco'] ?? 0) as num).toDouble();
          if (!history.containsKey(name) || (history[name] == 0.0 && price > 0)) {
            history[name] = price;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _productHistory = history;
        });
      }
    } catch (e) {
      debugPrint('Erro _loadHistory em shopping_list_screen: $e');
    }
  }

  Future<void> _addItem(String nome, double preco, double qtde) async {
    try {
      final supabase = SupabaseHelper.instance.client;
      final authId = supabase.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000000';

      await supabase.from('lista_compras').insert({
        'nome': nome.trim(),
        'quantidade': qtde,
        'preco': preco > 0 ? preco : null,
        'comprado': 0,
        'auth_id': authId,
      });
      await _loadItems();
      await _loadHistory();
    } catch (e) {
      debugPrint('Erro _addItem: $e');
    }
  }

  Future<void> _editItem(dynamic id, String nome, double preco, double qtde) async {
    try {
      final supabase = SupabaseHelper.instance.client;

      await supabase.from('lista_compras').update({
        'nome': nome.trim(),
        'preco': preco > 0 ? preco : null,
        'quantidade': qtde,
      }).eq('id', id.toString());
      
      await _loadItems();
      await _loadHistory();
    } catch (e) {
      debugPrint('Erro _editItem: $e');
    }
  }

  Future<void> _updateItem(String id, String nome, double preco, double qtde) async {
    final db = await SupabaseHelper.instance.database;
    
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

  Future<void> _showItemModal({Map<String, dynamic>? itemToEdit}) async {
    final prefs = await SharedPreferences.getInstance();

    final itemNome = (itemToEdit?['Nome'] ?? itemToEdit?['nome'] ?? '').toString().trim();
    final pKey = itemNome.toLowerCase();

    final nomeController = TextEditingController(text: itemNome);
    final precoController = TextEditingController();
    final qtdeController = TextEditingController();
    final precoUnitarioController = TextEditingController();

    String? savedModo = prefs.getString('prod_modo_$pKey');
    String modoCalculo = savedModo ?? 'Unidade';
    String unidadePeso = prefs.getString('prod_unidade_$pKey') ?? 'g';

    if (itemToEdit != null) {
      final qtde = _numToDouble(itemToEdit['Quantidade'] ?? itemToEdit['quantidade'], 1.0);
      final preco = _numToDouble(itemToEdit['Preco'] ?? itemToEdit['preco']);

      if (savedModo == null && (qtde % 1 != 0 || pKey.contains('kg') || pKey.contains('peso') || pKey.contains('tangerina') || pKey.contains('tomate'))) {
        modoCalculo = 'Peso';
      }

      if (modoCalculo == 'Peso') {
        if (unidadePeso == 'g') {
          qtdeController.text = (qtde * 1000).round().toString();
        } else {
          qtdeController.text = qtde.toString().replaceAll('.0', '');
        }
        if (preco > 0) {
          precoUnitarioController.text = CurrencyFormatter.format(preco);
          final total = preco * qtde;
          precoController.text = total > 0 ? CurrencyFormatter.format(total) : '';
        }
      } else {
        modoCalculo = 'Unidade';
        qtdeController.text = qtde.toString().replaceAll('.0', '');
        if (preco > 0) {
          precoUnitarioController.text = CurrencyFormatter.format(preco);
          final total = preco * qtde;
          precoController.text = total > 0 ? CurrencyFormatter.format(total) : '';
        }
      }
    } else {
      qtdeController.text = '1';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void recalculatePrice() {
              if (modoCalculo == 'Unidade') {
                final numericUnit = precoUnitarioController.text.replaceAll(RegExp('[^0-9]'), '');
                final unitPrice = numericUnit.isEmpty ? 0.0 : double.parse(numericUnit) / 100;
                final qtde = double.tryParse(qtdeController.text.replaceAll(',', '.')) ?? 1.0;
                final total = unitPrice * qtde;
                precoController.text = total > 0 ? CurrencyFormatter.format(total) : '';
              } else if (modoCalculo == 'Peso') {
                final numericKg = precoUnitarioController.text.replaceAll(RegExp('[^0-9]'), '');
                final pricePerKg = numericKg.isEmpty ? 0.0 : double.parse(numericKg) / 100;
                final rawWeight = double.tryParse(qtdeController.text.replaceAll(',', '.')) ?? 0.0;
                double weightInKg = rawWeight;
                if (unidadePeso == 'g') {
                  weightInKg = rawWeight / 1000.0;
                }
                final total = pricePerKg * weightInKg;
                precoController.text = total > 0 ? CurrencyFormatter.format(total) : '';
              }
            }

            // Check inflation vs unit/Kg price
            Widget inflationWidget = const SizedBox.shrink();
            final currentName = nomeController.text.trim();
            if (currentName.isNotEmpty && _productHistory.containsKey(currentName)) {
              final historicalPrice = _productHistory[currentName]!;

              final numericUnit = precoUnitarioController.text.replaceAll(RegExp('[^0-9]'), '');
              double currentUnitPrice = numericUnit.isEmpty ? 0.0 : double.parse(numericUnit) / 100;
              if (currentUnitPrice == 0) {
                final numericPreco = precoController.text.replaceAll(RegExp('[^0-9]'), '');
                final total = numericPreco.isEmpty ? 0.0 : double.parse(numericPreco) / 100;
                final qtde = double.tryParse(qtdeController.text.replaceAll(',', '.')) ?? 1.0;
                currentUnitPrice = qtde > 0 ? total / qtde : total;
              }

              if (currentUnitPrice > 0 && historicalPrice > 0) {
                final diff = currentUnitPrice - historicalPrice;
                if (diff.abs() >= 0.01) {
                  final pct = (diff / historicalPrice) * 100;
                  final unitLabel = modoCalculo == 'Peso' ? '/Kg' : '/Un';
                  if (diff > 0) {
                    inflationWidget = Text(
                      '+ ${CurrencyFormatter.format(diff)}$unitLabel (+${pct.toStringAsFixed(1)}%) vs histórico (${CurrencyFormatter.format(historicalPrice)}$unitLabel)',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                    );
                  } else {
                    inflationWidget = Text(
                      '- ${CurrencyFormatter.format(diff.abs())}$unitLabel (${pct.toStringAsFixed(1)}%) vs histórico (${CurrencyFormatter.format(historicalPrice)}$unitLabel)',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                    );
                  }
                }
              } else if (historicalPrice > 0) {
                final unitLabel = modoCalculo == 'Peso' ? '/Kg' : '/Un';
                inflationWidget = Text(
                  'Último preço: ${CurrencyFormatter.format(historicalPrice)}$unitLabel',
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
              child: SingleChildScrollView(
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
                          return !option.startsWith('prod_cat:') && option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        // handled by listener
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        controller.addListener(() {
                          if (nomeController.text != controller.text) {
                            nomeController.text = controller.text;
                            
                            final selection = controller.text;
                            if (_productHistory.containsKey(selection)) {
                              final pKey = selection.toLowerCase();
                              final savedModo = prefs.getString('prod_modo_$pKey');
                              
                              // Check if there is a saved mode, otherwise infer from name
                              if (savedModo != null) {
                                modoCalculo = savedModo;
                              } else if (pKey.contains('kg') || pKey.contains('peso') || pKey.contains('tangerina') || pKey.contains('tomate')) {
                                modoCalculo = 'Peso';
                              } else {
                                modoCalculo = 'Unidade';
                              }
                              
                              unidadePeso = prefs.getString('prod_unidade_$pKey') ?? 'g';
                              
                              if (modoCalculo == 'Unidade') {
                                qtdeController.text = '1';
                              } else {
                                qtdeController.text = unidadePeso == 'g' ? '1000' : '1.0';
                              }

                              // Não preenchemos o preço automaticamente: cada compra tem preço diferente
                              // e o usuário deve informar o valor atual.
                              precoUnitarioController.text = '';
                              precoController.text = '';
                              recalculatePrice();
                            }
                            
                            setModalState(() {});
                          }
                        });
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
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Unidade', label: Text('Por Unidade', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 'Peso', label: Text('Por Peso', style: TextStyle(fontSize: 12))),
                      ],
                      selected: {modoCalculo},
                      onSelectionChanged: (Set<String> newSelection) {
                        setModalState(() {
                          modoCalculo = newSelection.first;
                          if (modoCalculo == 'Unidade') {
                            qtdeController.text = '1';
                          } else {
                            qtdeController.text = unidadePeso == 'g' ? '1000' : '1.0';
                          }
                          recalculatePrice();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: precoUnitarioController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                            decoration: InputDecoration(
                              labelText: modoCalculo == 'Peso' ? r'Preço por Kg (R$)' : r'Preço Unitário (R$)',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setModalState(() => recalculatePrice()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: qtdeController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: modoCalculo == 'Peso' ? (unidadePeso == 'g' ? 'Peso (g)' : 'Peso (Kg)') : 'Quantidade (Un)',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setModalState(() => recalculatePrice()),
                          ),
                        ),
                      ],
                    ),
                    if (modoCalculo == 'Peso') ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Unidade de Peso: ', style: TextStyle(fontSize: 11, color: AppColors.secondaryText(context))),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'g', label: Text('Gramas (g)', style: TextStyle(fontSize: 10))),
                              ButtonSegment(value: 'kg', label: Text('Quilos (Kg)', style: TextStyle(fontSize: 10))),
                            ],
                            selected: {unidadePeso},
                            onSelectionChanged: (Set<String> sel) {
                              setModalState(() {
                                final novaUnidade = sel.first;
                                final rawWeight = double.tryParse(qtdeController.text.replaceAll(',', '.')) ?? 0.0;
                                if (rawWeight > 0) {
                                  if (unidadePeso == 'g' && novaUnidade == 'kg') {
                                    qtdeController.text = (rawWeight / 1000.0).toString().replaceAll('.0', '');
                                  } else if (unidadePeso == 'kg' && novaUnidade == 'g') {
                                    qtdeController.text = (rawWeight * 1000.0).round().toString();
                                  }
                                }
                                unidadePeso = novaUnidade;
                                recalculatePrice();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: precoController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: r'Preço Total Estimado (R$)',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calculate, color: Colors.green),
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                    const SizedBox(height: 8),
                    inflationWidget,
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      onPressed: () async {
                        final nome = nomeController.text.trim();
                        if (nome.isNotEmpty) {
                          final numericUnit = precoUnitarioController.text.replaceAll(RegExp('[^0-9]'), '');
                          final unitPriceInput = numericUnit.isEmpty ? 0.0 : double.parse(numericUnit) / 100;

                          final numericTotal = precoController.text.replaceAll(RegExp('[^0-9]'), '');
                          final totalInput = numericTotal.isEmpty ? 0.0 : double.parse(numericTotal) / 100;

                          double finalPrice = unitPriceInput;
                          double finalQtde = 1.0;

                          if (modoCalculo == 'Unidade') {
                            finalQtde = double.tryParse(qtdeController.text.replaceAll(',', '.')) ?? 1.0;
                            if (finalPrice == 0 && totalInput > 0 && finalQtde > 0) {
                              finalPrice = totalInput / finalQtde;
                            }
                          } else if (modoCalculo == 'Peso') {
                            final rawWeight = double.tryParse(qtdeController.text.replaceAll(',', '.')) ?? 1000.0;
                            finalQtde = unidadePeso == 'g' ? (rawWeight / 1000.0) : rawWeight;
                            if (finalPrice == 0 && totalInput > 0 && finalQtde > 0) {
                              finalPrice = totalInput / finalQtde;
                            }
                          }

                          try {
                            final pK = nome.toLowerCase();
                            await prefs.setString('prod_modo_$pK', modoCalculo);
                            await prefs.setString('prod_unidade_$pK', unidadePeso);
                          } catch (_) {}

                          if (itemToEdit == null) {
                            _addItem(nome, finalPrice, finalQtde).then((_) => _loadHistory());
                          } else {
                            _updateItem(itemToEdit['ID'], nome, finalPrice, finalQtde).then((_) => _loadHistory());
                          }
                          if (mounted) Navigator.pop(ctx);
                        }
                      },
                      child: Text(itemToEdit == null ? 'Adicionar à Lista' : 'Salvar Alterações'),
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

  double _numToDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? fallback;
  }

  Future<void> _finalizarCompra() async {
    final comprados = _items.where((i) => i['Comprado'] == 1 || i['comprado'] == 1).toList();
    if (comprados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marque pelo menos um item como comprado.')));
      return;
    }

    double total = 0;
    List<String> ids = [];
    for (var item in comprados) {
      final p = _numToDouble(item['Preco'] ?? item['preco']);
      final q = _numToDouble(item['Quantidade'] ?? item['quantidade'], 1.0);
      total += p * q;
      ids.add((item['ID'] ?? item['id']).toString());
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
      final p = _numToDouble(item['Preco'] ?? item['preco']);
      final q = _numToDouble(item['Quantidade'] ?? item['quantidade'], 1.0);
      final val = p * q;
      totalPrevisto += val;
      if (item['Comprado'] == 1 || item['comprado'] == 1) totalCarrinho += val;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Compras', style: TextStyle(fontSize: 16)),
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
            onPressed: _items.any((i) => (i['Comprado'] == 1 || i['comprado'] == 1)) ? _finalizarCompra : null,
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
                          Text('Previsto', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 12)),
                          Text(CurrencyFormatter.format(totalPrevisto), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('No Carrinho', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 12)),
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
                            final isComprado = (item['Comprado'] == 1 || item['comprado'] == 1);
                            final precoVal = _numToDouble(item['Preco'] ?? item['preco']);
                            final qtdeVal = _numToDouble(item['Quantidade'] ?? item['quantidade'], 1.0);
                            final totalItem = precoVal * qtdeVal;
                            final itemId = (item['ID'] ?? item['id'] ?? index).toString();
                            final itemNome = (item['Nome'] ?? item['nome'] ?? '').toString();
                            
                            return Dismissible(
                              key: Key(itemId),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text('Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 8),
                                    Icon(Icons.delete, color: Colors.white),
                                  ],
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Remover Item?'),
                                    content: Text('Deseja remover "$itemNome" da sua lista de compras?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: const Text('Excluir', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ) ?? false;
                              },
                              onDismissed: (_) async {
                                await _deleteItem(itemId);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Item "$itemNome" removido'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              child: ListTile(
                                leading: Checkbox(
                                  value: isComprado,
                                  onChanged: (_) => _toggleItem(itemId, isComprado ? 1 : 0),
                                ),
                                title: Text(itemNome, style: TextStyle(decoration: isComprado ? TextDecoration.lineThrough : null)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Builder(
                                        builder: (context) {
                                          final pKey = itemNome.toLowerCase();
                                          final isPeso = pKey.contains('kg') || pKey.contains('peso') || pKey.contains('tangerina') || pKey.contains('tomate') || (qtdeVal > 0 && qtdeVal < 1.0) || (qtdeVal % 1 != 0);
                                          
                                          if (isPeso) {
                                            if (qtdeVal < 1.0 && qtdeVal > 0) {
                                              return Text('${(qtdeVal * 1000).round()}g x ${CurrencyFormatter.format(precoVal)}/Kg');
                                            } else {
                                              return Text('${qtdeVal.toStringAsFixed(3).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '')}Kg x ${CurrencyFormatter.format(precoVal)}/Kg');
                                            }
                                          } else {
                                            return Text('${qtdeVal.toString().replaceAll('.0', '')}x ${CurrencyFormatter.format(precoVal)}');
                                          }
                                        },
                                      ),
                                    if (_productHistory.containsKey(itemNome.trim()) && precoVal > 0)
                                      Builder(builder: (ctx) {
                                        final hist = _productHistory[itemNome.trim()]!;
                                        final curr = precoVal;
                                        if (hist > 0 && curr != hist) {
                                          final diff = curr - hist;
                                          final pct = (diff / hist) * 100;
                                          if (diff > 0) {
                                            return Text(
                                              '+ ${CurrencyFormatter.format(diff)} (+${pct.toStringAsFixed(1)}%) vs histórico (${CurrencyFormatter.format(hist)})',
                                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                            );
                                          } else {
                                            return Text(
                                              '- ${CurrencyFormatter.format(diff.abs())} (${pct.toStringAsFixed(1)}%) vs histórico (${CurrencyFormatter.format(hist)})',
                                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                                            );
                                          }
                                        }
                                        return const SizedBox.shrink();
                                      }),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      CurrencyFormatter.format(totalItem),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isComprado ? Colors.grey : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.edit, size: 16, color: AppColors.iconMuted(context)),
                                  ],
                                ),
                                onTap: () => _showItemModal(itemToEdit: item),
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
