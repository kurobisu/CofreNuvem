import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/supabase_helper.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/app_colors.dart';
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
    try {
      final supabase = SupabaseHelper.instance.client;
      
      final catsRes = await supabase.from('categorias').select().neq('tipo', 'Receita').eq('oculta', 0).filter('deleted_at', 'is', null).order('nome', ascending: true);
      _categorias = catsRes;

      final Map<String, Map<String, dynamic>> catsMap = {};
      for (var cRaw in catsRes) {
        final c = CaseInsensitiveMap(cRaw as Map<String, dynamic>);
        catsMap[(c['id'] ?? c['ID'])?.toString() ?? ''] = c;
      }

      final listaComprasRaw = await supabase.from('lista_compras')
          .select()
          .filter('deleted_at', 'is', null)
          .order('id', ascending: false);
          
      final prefs = await SharedPreferences.getInstance();
      Map<String, Map<String, dynamic>> productsMap = {};
      final Map<String, String> onlineProdCats = {};

      for (var lcRaw in listaComprasRaw) {
        final lc = CaseInsensitiveMap(lcRaw as Map<String, dynamic>);
        String lcName = (lc['nome'] ?? '').toString().trim();
        if (lcName.isEmpty) continue;

        if (lcName.startsWith('prod_cat:')) {
          final parts = lcName.split(':');
          if (parts.length >= 3) {
            final pName = parts[1].toLowerCase().trim();
            final catId = parts[2].trim();
            if (!onlineProdCats.containsKey(pName) && catId.isNotEmpty) {
              onlineProdCats[pName] = catId;
            }
          }
          continue;
        }

        final key = lcName.toLowerCase();
        String? catId = lc['categoria_id']?.toString() ?? onlineProdCats[key] ?? prefs.getString('prod_cat_$key');
        final catMap = catId != null ? catsMap[catId] : null;
        double preco = ((lc['preco'] ?? 0) as num).toDouble();

        if (!productsMap.containsKey(key)) {
          productsMap[key] = {
            'ID': lc['id']?.toString() ?? key,
            'Nome': lcName,
            'Categoria_ID': catId,
            'CategoriaNome': catMap?['nome'] ?? catMap?['Nome'] ?? 'Sem Categoria',
            'Cor_Hexadecimal': catMap?['cor_hexadecimal'] ?? catMap?['Cor_Hexadecimal'] ?? '#9E9E9E',
            'Prices': <double>[],
            'BuyCount': 0,
          };
        }

        productsMap[key]!['BuyCount'] = (productsMap[key]!['BuyCount'] as int) + 1;
        if (preco > 0) {
          (productsMap[key]!['Prices'] as List<double>).add(preco);
        }
      }

      List<Map<String, dynamic>> stats = [];
      productsMap.forEach((key, data) {
        List<double> prices = data['Prices'];
        
        double currentPrice = 0;
        double maxPrice = 0;
        double minPrice = 0;
        double previousPrice = 0;
        
        if (prices.isNotEmpty) {
          currentPrice = prices.first;
          maxPrice = prices.reduce((curr, next) => curr > next ? curr : next);
          minPrice = prices.reduce((curr, next) => curr < next ? curr : next);
          previousPrice = prices.length > 1 ? prices[1] : currentPrice;
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

      stats.sort((a, b) => (a['Nome'] ?? '').toString().toLowerCase().compareTo((b['Nome'] ?? '').toString().toLowerCase()));

      if (mounted) {
        setState(() {
          _productStats = stats;
          _filteredStats = stats;
        });
      }
    } catch (e) {
      debugPrint('Erro _loadHistory no product_history_screen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query;
      _filteredStats = _productStats.where((p) {
        return p['Nome'].toString().toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _showPriceHistory(String productId, String productName) async {
    final supabase = SupabaseHelper.instance.client;
    
    // Simulating the JOIN: find lista_compras where name = productName
    final resultRaw = await supabase.from('lista_compras')
        .select('preco, transacoes(data)')
        .eq('nome', productName)
        .not('transacao_id', 'is', null)
        .filter('deleted_at', 'is', null);
        
    final result = resultRaw.map((r) => {
      'Preco': r['preco'],
      'Data': r['transacoes']?['data'] ?? '',
    }).toList();
    result.sort((a, b) => (b['Data']?.toString() ?? '').compareTo(a['Data']?.toString() ?? ''));

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
                      final dateStr = (row['Data'] ?? row['data'] ?? '').toString();
                      final price = ((row['Preco'] ?? row['preco'] ?? 0) as num).toDouble();
                      final date = DateTime.tryParse(dateStr) ?? DateTime.now();
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

  Future<void> _deleteProduct(String nome) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Produto'),
        content: const Text('Tem certeza que deseja excluir este produto do histórico?'),
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
      final supabase = SupabaseHelper.instance.client;
      await supabase.from('lista_compras').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).filter('nome', 'eq', nome);
      _loadHistory();
    }
  }

  List<Map<String, dynamic>> _buildStructuredCategories(List<dynamic> rawCats) {
    final clean = rawCats.map((c) => CaseInsensitiveMap(c as Map<String, dynamic>)).toList();
    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var c in clean) {
      final name = (c['nome'] ?? '').toString().trim();
      final pId = (c['parent_id'] ?? 'root').toString();
      final key = '${name.toLowerCase()}_$pId';
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = c;
      }
    }
    final allCats = uniqueMap.values.toList();

    final keywords = ['mercado', 'saúde', 'saude', 'farmác', 'farmac', 'higiene', 'limpeza', 'pet', 'alimento', 'hortifruti', 'açougue', 'padaria', 'bebida', 'mercearia', 'frio', 'congelado', 'biscoito', 'guloseima'];

    bool isRelevant(Map<String, dynamic> c) {
      final name = (c['nome'] ?? '').toString().toLowerCase();
      final parentId = (c['parent_id'])?.toString();
      if (keywords.any((kw) => name.contains(kw))) return true;
      if (parentId != null && parentId != 'null') {
        final parent = allCats.firstWhere((p) => (p['id'] ?? p['ID'])?.toString() == parentId, orElse: () => {});
        if (parent.isNotEmpty) {
          final parentName = (parent['nome'] ?? '').toString().toLowerCase();
          if (keywords.any((kw) => parentName.contains(kw))) return true;
        }
      }
      return false;
    }

    final filteredCats = allCats.where(isRelevant).toList();

    final parents = filteredCats.where((c) => c['parent_id'] == null || c['parent_id'] == 'null').toList();
    parents.sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));

    List<Map<String, dynamic>> structured = [];
    for (var p in parents) {
      structured.add(p);
      final children = filteredCats.where((c) => (c['parent_id']?.toString() ?? '') == (p['id']?.toString() ?? '')).toList();
      children.sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));
      for (var child in children) {
        structured.add(child);
      }
    }
    return structured;
  }

  Future<void> _showProductDialog([Map<String, dynamic>? product]) async {
    final nomeController = TextEditingController(text: product?['Nome'] ?? '');
    
    double initialPrice = 0.0;
    if (product != null) {
      initialPrice = ((product['CurrentPrice'] ?? product['Preco'] ?? product['preco'] ?? 0) as num).toDouble();
    }
    final precoUnitarioController = TextEditingController(
      text: initialPrice > 0 ? CurrencyFormatter.format(initialPrice) : '',
    );
    final pesoOuQtdeController = TextEditingController(text: '1');

    final prefs = await SharedPreferences.getInstance();
    final initialKey = (product?['Nome'] ?? '').toString().trim().toLowerCase();
    String? selectedCategoria = product?['Categoria_ID']?.toString();
    if ((selectedCategoria == null || selectedCategoria.isEmpty) && initialKey.isNotEmpty) {
      selectedCategoria = prefs.getString('prod_cat_$initialKey');
    }

    String modoCalculo = prefs.getString('prod_modo_$initialKey') ?? 'Unidade';
    String unidadePeso = prefs.getString('prod_unidade_$initialKey') ?? 'g';

    if (product != null && prefs.getString('prod_modo_$initialKey') == null) {
      if (initialKey.contains('kg') || initialKey.contains('peso') || initialKey.contains('tangerina') || initialKey.contains('tomate')) {
        modoCalculo = 'Peso';
      }
    }

    final structuredCats = _buildStructuredCategories(_categorias);
    final validCatIds = structuredCats.map((c) => (c['id'] ?? c['ID'])?.toString()).whereType<String>().toSet();
    if (selectedCategoria != null && !validCatIds.contains(selectedCategoria)) {
      selectedCategoria = null;
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            scrollable: true,
            title: Text(product == null ? 'Novo Produto na Biblioteca' : 'Editar Produto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(labelText: 'Nome do Produto'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategoria,
                  menuMaxHeight: 280,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoria / Área'),
                  items: structuredCats.map((c) {
                    final cId = (c['id'] ?? c['ID'])?.toString();
                    final cNome = (c['nome'] ?? c['Nome'] ?? 'Sem Categoria').toString();
                    final colorHex = (c['cor_hexadecimal'] ?? c['Cor_Hexadecimal'] ?? '#9E9E9E').toString().replaceAll('#', '0xFF');
                    final isChild = c['parent_id'] != null && c['parent_id'] != 'null';

                    return DropdownMenuItem<String>(
                      value: cId,
                      child: Row(
                        children: [
                          if (isChild) const SizedBox(width: 12),
                          if (isChild) Icon(Icons.subdirectory_arrow_right, size: 14, color: AppColors.iconMuted(context)),
                          if (isChild) const SizedBox(width: 4),
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: Color(int.parse(colorHex)),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              cNome,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isChild ? FontWeight.normal : FontWeight.bold,
                                fontSize: isChild ? 12 : 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setStateDialog(() => selectedCategoria = val),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Unidade', label: Text('Por Unidade', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'Peso', label: Text('Por Peso', style: TextStyle(fontSize: 12))),
                  ],
                  selected: {modoCalculo},
                  onSelectionChanged: (Set<String> newSelection) {
                    setStateDialog(() {
                      modoCalculo = newSelection.first;
                      if (modoCalculo == 'Unidade') {
                        pesoOuQtdeController.text = '1';
                      } else {
                        pesoOuQtdeController.text = unidadePeso == 'g' ? '1000' : '1.0';
                      }
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
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: pesoOuQtdeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: modoCalculo == 'Peso' ? (unidadePeso == 'g' ? 'Peso (g)' : 'Peso (Kg)') : 'Quantidade (Un)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                if (modoCalculo == 'Peso') ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Unidade: ', style: TextStyle(fontSize: 11, color: AppColors.secondaryText(context))),
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'g', label: Text('Gramas (g)', style: TextStyle(fontSize: 10))),
                            ButtonSegment(value: 'kg', label: Text('Quilos (Kg)', style: TextStyle(fontSize: 10))),
                          ],
                          selected: {unidadePeso},
                          onSelectionChanged: (Set<String> sel) {
                            setStateDialog(() {
                              final novaUnidade = sel.first;
                              final rawWeight = double.tryParse(pesoOuQtdeController.text.replaceAll(',', '.')) ?? 0.0;
                              if (rawWeight > 0) {
                                if (unidadePeso == 'g' && novaUnidade == 'kg') {
                                  pesoOuQtdeController.text = (rawWeight / 1000.0).toString().replaceAll('.0', '');
                                } else if (unidadePeso == 'kg' && novaUnidade == 'g') {
                                  pesoOuQtdeController.text = (rawWeight * 1000.0).round().toString();
                                }
                              }
                              unidadePeso = novaUnidade;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final nome = nomeController.text.trim();
                  if (nome.isEmpty) return;

                  try {
                    final supabase = SupabaseHelper.instance.client;
                    final authId = supabase.auth.currentUser?.id;

                    final numericUnit = precoUnitarioController.text.replaceAll(RegExp('[^0-9]'), '');
                    final unitPriceInput = numericUnit.isEmpty ? 0.0 : double.parse(numericUnit) / 100;

                    double finalPrice = unitPriceInput;
                    double finalQtde = 1.0;

                    if (modoCalculo == 'Unidade') {
                      finalQtde = double.tryParse(pesoOuQtdeController.text.replaceAll(',', '.')) ?? 1.0;
                    } else if (modoCalculo == 'Peso') {
                      final rawWeight = double.tryParse(pesoOuQtdeController.text.replaceAll(',', '.')) ?? 1000.0;
                      finalQtde = unidadePeso == 'g' ? (rawWeight / 1000.0) : rawWeight;
                    }

                    final Map<String, dynamic> itemData = {
                      'nome': nome,
                      'quantidade': finalQtde,
                      'comprado': 2,
                    };
                    if (finalPrice > 0) itemData['preco'] = finalPrice;
                    if (authId != null) itemData['auth_id'] = authId;

                    if (product == null) {
                      await supabase.from('lista_compras').insert(itemData);
                    } else {
                      await supabase.from('lista_compras').update(itemData).filter('nome', 'eq', product['Nome']);
                    }

                    final prefs = await SharedPreferences.getInstance();
                    final prodKey = nome.toLowerCase();
                    await prefs.setString('prod_modo_$prodKey', modoCalculo);
                    await prefs.setString('prod_unidade_$prodKey', unidadePeso);

                    final onlineCatPrefix = 'prod_cat:$prodKey:';

                    try {
                      await supabase.from('lista_compras').delete().filter('nome', 'like', 'prod_cat:$prodKey:%');
                    } catch (_) {}

                    if (selectedCategoria != null && selectedCategoria!.isNotEmpty) {
                      await prefs.setString('prod_cat_$prodKey', selectedCategoria!);
                      try {
                        await supabase.from('lista_compras').insert({
                          'nome': '$onlineCatPrefix${selectedCategoria!}',
                          'comprado': -1,
                          'quantidade': 0,
                          'preco': 0,
                          if (authId != null) 'auth_id': authId,
                        });
                      } catch (_) {}
                    } else {
                      await prefs.remove('prod_cat_$prodKey');
                    }

                    if (mounted) {
                      Navigator.pop(ctx);
                      _loadHistory();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao salvar produto: $e')),
                      );
                    }
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopProductsChart() {
    List<Map<String, dynamic>> sortedByBuy = List.from(_productStats);
    sortedByBuy.sort((a, b) => (b['BuyCount'].toString()).compareTo(a['BuyCount'].toString()));
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
                    onTap: () => _showPriceHistory(p['ID'].toString(), p['Nome'] as String),
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
                  variationWidget = Text('Estável', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 12, fontWeight: FontWeight.bold));
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
                          if (stat['HistoryCount'] == 0) Text('S/ Histórico', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 12)),
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
                                  Text('Menor Preço', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context))),
                                  Text(stat['HistoryCount'] > 0 ? CurrencyFormatter.format(stat['MinPrice'] as double) : '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                ],
                              ),
                              Column(
                                children: [
                                  Text('Maior Preço', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context))),
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
                              onPressed: () => _showPriceHistory(stat['ID'].toString(), stat['Nome'] as String),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showProductDialog(stat),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProduct(stat['ID'].toString()),
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
