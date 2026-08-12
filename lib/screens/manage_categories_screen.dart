import 'package:flutter/material.dart';
import '../database/supabase_helper.dart';
import '../utils/default_data.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  List<Map<String, dynamic>> _categorias = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategorias();
  }

  Future<void> _loadCategorias() async {
    await DefaultData.seedDefaultCategories();
    final db = await SupabaseHelper.instance.database;
    final cats = await db.query(SupabaseHelper.tableCategorias, orderBy: 'Parent_ID ASC, Nome ASC');
    if (mounted) {
      setState(() {
        _categorias = List<Map<String, dynamic>>.from(cats);
        _isLoading = false;
      });
    }
  }

  Future<void> _addCategory(String nome, String hexColor, String tipo, String? parentId) async {
    final db = await SupabaseHelper.instance.database;
    await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': nome,
      'Cor_Hexadecimal': hexColor,
      'Tipo': tipo,
      'Parent_ID': parentId,
      'Oculta': 0,
      'Ordem': 0,
    });
    _loadCategorias();
  }

  Future<void> _updateCategory(String id, String nome, String hexColor, String tipo, String? parentId) async {
    final db = await SupabaseHelper.instance.database;
    await db.update(SupabaseHelper.tableCategorias, {
      'Nome': nome,
      'Cor_Hexadecimal': hexColor,
      'Tipo': tipo,
      'Parent_ID': parentId,
    }, where: 'ID = ?', whereArgs: [id]);
    _loadCategorias();
  }

  Future<void> _deleteCategory(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Categoria'),
        content: const Text('As subcategorias ficarão sem categoria pai, e as despesas/produtos vinculados ficarão sem categoria. Confirma exclusão?'),
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
      final db = await SupabaseHelper.instance.database;
      // 1. Unlink children
      await db.update(SupabaseHelper.tableCategorias, {'Parent_ID': null}, where: 'Parent_ID = ?', whereArgs: [id]);
      // 2. Unlink products
      await db.update(SupabaseHelper.tableProdutos, {'Categoria_ID': null}, where: 'Categoria_ID = ?', whereArgs: [id]);
      // 3. Unlink transactions
      await db.update(SupabaseHelper.tableTransacoes, {'Categoria_ID': null}, where: 'Categoria_ID = ?', whereArgs: [id]);
      
      await db.delete(SupabaseHelper.tableCategorias, where: 'ID = ?', whereArgs: [id]);
      _loadCategorias();
    }
  }

  Future<void> _toggleOculta(String id, int atual) async {
    final db = await SupabaseHelper.instance.database;
    await db.update(SupabaseHelper.tableCategorias, {'Oculta': atual == 0 ? 1 : 0}, where: 'ID = ?', whereArgs: [id]);
    _loadCategorias();
  }

  void _showCategoryDialog([Map<String, dynamic>? category, String? preselectedParent]) {
    final nomeController = TextEditingController(text: category?['Nome'] ?? '');
    String selectedColor = category?['Cor_Hexadecimal'] ?? '#2196F3';
    String selectedTipo = category?['Tipo'] ?? 'Despesa';
    String? selectedParentId = category?['Parent_ID']?.toString() ?? preselectedParent;

    final colors = [
      '#F44336', '#E91E63', '#9C27B0', '#673AB7',
      '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
      '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
      '#FFEB3B', '#FFC107', '#FF9800', '#FF5722',
      '#795548', '#9E9E9E', '#607D8B', '#000000',
    ];
    final tipos = ['Ambas', 'Despesa', 'Receita'];

    // Only parents (Parent_ID is null) can be selected as parent
    // Also prevent a category from being its own parent
    final parentOptions = _categorias.where((c) => c['Parent_ID'] == null && (category == null || c['ID'] != category['ID'])).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      category == null ? 'Nova Categoria' : 'Editar Categoria',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (category != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Excluir',
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        _deleteCategory(category['ID']); // Trigger delete
                      },
                    )
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome da Categoria'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedTipo,
                      items: tipos.map((t) => DropdownMenuItem(value: t, child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setStateDialog(() => selectedTipo = val!),
                      decoration: const InputDecoration(labelText: 'Tipo de Categoria'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      value: selectedParentId,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Nenhuma (Categoria Principal)', maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ...parentOptions.map((p) => DropdownMenuItem<String?>(
                          value: p['ID'].toString(),
                          child: Text(p['Nome'], maxLines: 1, overflow: TextOverflow.ellipsis),
                        )).toList()
                      ],
                      onChanged: (val) {
                        setStateDialog(() {
                          selectedParentId = val;
                          if (val != null) {
                            final parent = parentOptions.firstWhere((p) => p['ID'] == val);
                            selectedTipo = parent['Tipo'];
                            selectedColor = parent['Cor_Hexadecimal'];
                          }
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Sub-categoria de:'),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Cor da Categoria:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: colors.map((color) {
                        final c = Color(int.parse(color.replaceAll('#', '0xFF')));
                        return GestureDetector(
                          onTap: () => setStateDialog(() => selectedColor = color),
                          child: CircleAvatar(
                            backgroundColor: c,
                            child: selectedColor == color ? const Icon(Icons.check, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (nomeController.text.trim().isNotEmpty) {
                      if (category == null) {
                        _addCategory(nomeController.text.trim(), selectedColor, selectedTipo, selectedParentId);
                      } else {
                        _updateCategory(category['ID'], nomeController.text.trim(), selectedColor, selectedTipo, selectedParentId);
                      }
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Salvar'),
                )
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildCategoryList(List<Map<String, dynamic>> parents, List<Map<String, dynamic>> allCategories) {
    if (parents.isEmpty) {
      return const Center(child: Text('Nenhuma categoria encontrada.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16).copyWith(bottom: 80), // extra padding for FAB
      itemCount: parents.length,
      itemBuilder: (context, index) {
        final parent = parents[index];
        final children = allCategories.where((c) => c['Parent_ID'] == parent['ID']).toList();
        
        final parentColor = Color(int.parse(parent['Cor_Hexadecimal'].toString().replaceAll('#', '0xFF')));
        final isHidden = parent['Oculta'] == 1;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: parentColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(parent['Nome'], style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, decoration: isHidden ? TextDecoration.lineThrough : null)),
                          Text(parent['Tipo'], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.add, color: Colors.green),
                          tooltip: 'Nova Sub-categoria',
                          onPressed: () => _showCategoryDialog(null, parent['ID'].toString()),
                        ),
                        const SizedBox(width: 4),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: !isHidden,
                            onChanged: (val) => _toggleOculta(parent['ID'].toString(), parent['Oculta']),
                            activeColor: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.edit, color: Colors.grey),
                          onPressed: () => _showCategoryDialog(parent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (children.isNotEmpty)
                const Divider(height: 1),
              if (children.isNotEmpty)
                ...children.map((child) {
                  final childHidden = child['Oculta'] == 1;
                  return Padding(
                    padding: const EdgeInsets.only(left: 40.0, right: 12.0, top: 4, bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.subdirectory_arrow_right, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(child['Nome'], style: TextStyle(color: Colors.white, fontSize: 15, decoration: childHidden ? TextDecoration.lineThrough : null)),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: !childHidden,
                                onChanged: (val) => _toggleOculta(child['ID'].toString(), child['Oculta']),
                                activeColor: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                              onPressed: () => _showCategoryDialog(child),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gerenciar Categorias')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final allParents = _categorias.where((c) => c['Parent_ID'] == null).toList();
    
    // Filtros para as Abas
    final receitasParents = allParents.where((c) => c['Tipo'] == 'Receita').toList();
    
    final mercadoParent = allParents.where((c) => c['Nome'] == 'Mercado').toList();
    final mercadoId = mercadoParent.isNotEmpty ? mercadoParent.first['ID'] : null;
    
    final despesasParents = allParents.where((c) => c['Tipo'] == 'Despesa' && c['Nome'] != 'Mercado').toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categorias'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.arrow_upward, color: Colors.green), text: 'Receitas'),
              Tab(icon: Icon(Icons.arrow_downward, color: Colors.red), text: 'Despesas'),
              Tab(icon: Icon(Icons.shopping_cart, color: Colors.orange), text: 'Mercado'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCategoryList(receitasParents, _categorias),
            _buildCategoryList(despesasParents, _categorias),
            _buildCategoryList(mercadoParent, _categorias),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCategoryDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Nova Categoria Padrão'),
        ),
      ),
    );
  }
}
