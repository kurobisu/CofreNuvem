import 'package:flutter/material.dart';
import '../database/database_helper.dart';

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
    final db = await DatabaseHelper.instance.database;
    final cats = await db.query(DatabaseHelper.tableCategorias, orderBy: 'Parent_ID ASC, Nome ASC');
    setState(() {
      _categorias = List<Map<String, dynamic>>.from(cats);
      _isLoading = false;
    });
  }

  Future<void> _addCategory(String nome, String hexColor, String tipo, int? parentId) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(DatabaseHelper.tableCategorias, {
      'Nome': nome,
      'Cor_Hexadecimal': hexColor,
      'Tipo': tipo,
      'Parent_ID': parentId,
      'Oculta': 0,
      'Ordem': 0,
    });
    _loadCategorias();
  }

  Future<void> _updateCategory(int id, String nome, String hexColor, String tipo, int? parentId) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(DatabaseHelper.tableCategorias, {
      'Nome': nome,
      'Cor_Hexadecimal': hexColor,
      'Tipo': tipo,
      'Parent_ID': parentId,
    }, where: 'ID = ?', whereArgs: [id]);
    _loadCategorias();
  }

  Future<void> _deleteCategory(int id) async {
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
      final db = await DatabaseHelper.instance.database;
      // 1. Unlink children
      await db.update(DatabaseHelper.tableCategorias, {'Parent_ID': null}, where: 'Parent_ID = ?', whereArgs: [id]);
      // 2. Unlink products
      await db.update(DatabaseHelper.tableProdutos, {'Categoria_ID': null}, where: 'Categoria_ID = ?', whereArgs: [id]);
      // 3. Unlink transactions
      await db.update(DatabaseHelper.tableTransacoes, {'Categoria_ID': null}, where: 'Categoria_ID = ?', whereArgs: [id]);
      
      await db.delete(DatabaseHelper.tableCategorias, where: 'ID = ?', whereArgs: [id]);
      _loadCategorias();
    }
  }

  Future<void> _toggleOculta(int id, int atual) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(DatabaseHelper.tableCategorias, {'Oculta': atual == 0 ? 1 : 0}, where: 'ID = ?', whereArgs: [id]);
    _loadCategorias();
  }

  void _showCategoryDialog([Map<String, dynamic>? category, int? preselectedParent]) {
    final nomeController = TextEditingController(text: category?['Nome'] ?? '');
    String selectedColor = category?['Cor_Hexadecimal'] ?? '#2196F3';
    String selectedTipo = category?['Tipo'] ?? 'Despesa';
    int? selectedParentId = category != null ? category['Parent_ID'] : preselectedParent;

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
                  Text(category == null ? 'Nova Categoria' : 'Editar Categoria'),
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
                      value: selectedTipo,
                      items: tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setStateDialog(() => selectedTipo = val!),
                      decoration: const InputDecoration(labelText: 'Tipo de Categoria'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      value: selectedParentId,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Nenhuma (Categoria Principal)')),
                        ...parentOptions.map((p) => DropdownMenuItem<int?>(
                          value: p['ID'] as int,
                          child: Text(p['Nome']),
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

  @override
  Widget build(BuildContext context) {
    // Build tree
    final parents = _categorias.where((c) => c['Parent_ID'] == null).toList();
    
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Categorias')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: parents.length,
              itemBuilder: (context, index) {
                final parent = parents[index];
                final children = _categorias.where((c) => c['Parent_ID'] == parent['ID']).toList();
                
                final parentColor = Color(int.parse(parent['Cor_Hexadecimal'].toString().replaceAll('#', '0xFF')));
                final isHidden = parent['Oculta'] == 1;

                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(backgroundColor: parentColor),
                      title: Text(parent['Nome'], style: TextStyle(fontWeight: FontWeight.bold, decoration: isHidden ? TextDecoration.lineThrough : null)),
                      subtitle: Text(parent['Tipo']),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.green),
                            tooltip: 'Nova Sub-categoria',
                            onPressed: () => _showCategoryDialog(null, parent['ID']),
                          ),
                          IconButton(
                            icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility, color: isHidden ? Colors.grey : Colors.blue),
                            onPressed: () => _toggleOculta(parent['ID'], parent['Oculta']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.grey),
                            onPressed: () => _showCategoryDialog(parent),
                          ),
                        ],
                      ),
                    ),
                    if (children.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 32.0),
                        child: Column(
                          children: children.map((child) {
                            final childHidden = child['Oculta'] == 1;
                            return ListTile(
                              leading: const Icon(Icons.subdirectory_arrow_right, color: Colors.grey),
                              title: Text(child['Nome'], style: TextStyle(decoration: childHidden ? TextDecoration.lineThrough : null)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(childHidden ? Icons.visibility_off : Icons.visibility, color: childHidden ? Colors.grey : Colors.blue, size: 20),
                                    onPressed: () => _toggleOculta(child['ID'], child['Oculta']),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                                    onPressed: () => _showCategoryDialog(child),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const Divider(),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
