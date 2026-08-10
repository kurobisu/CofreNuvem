import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';

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
    final cats = await db.query(DatabaseHelper.tableCategorias, orderBy: 'Ordem ASC');
    setState(() {
      _categorias = List<Map<String, dynamic>>.from(cats); // Make modifiable
      _isLoading = false;
    });
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _categorias.removeAt(oldIndex);
      _categorias.insert(newIndex, item);
    });

    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    for (int i = 0; i < _categorias.length; i++) {
      batch.update(DatabaseHelper.tableCategorias, {'Ordem': i}, where: 'ID = ?', whereArgs: [_categorias[i]['ID']]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _addCategory(String nome, String hexColor, String tipo) async {
    final db = await DatabaseHelper.instance.database;
    final maxOrdem = _categorias.isEmpty ? 0 : _categorias.length;
    await db.insert(DatabaseHelper.tableCategorias, {
      'Nome': nome,
      'Cor_Hexadecimal': hexColor,
      'Tipo': tipo,
      'Ordem': maxOrdem,
    });
    _loadCategorias();
  }

  Future<void> _deleteCategory(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableCategorias, where: 'ID = ?', whereArgs: [id]);
    _loadCategorias();
  }

  void _showAddDialog() {
    final nomeController = TextEditingController();
    String selectedColor = '#2196F3'; // Default blue
    String selectedTipo = 'Ambas';

    final colors = [
      '#F44336', '#E91E63', '#9C27B0', '#673AB7',
      '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
      '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
      '#FFEB3B', '#FFC107', '#FF9800', '#FF5722',
      '#795548', '#9E9E9E', '#607D8B', '#000000',
    ];
    final tipos = ['Ambas', 'Despesa', 'Receita'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Nova Categoria'),
              content: Column(
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
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (nomeController.text.trim().isNotEmpty) {
                      _addCategory(nomeController.text.trim(), selectedColor, selectedTipo);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Categorias')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              onReorder: _onReorder,
              padding: const EdgeInsets.all(16),
              itemCount: _categorias.length,
              itemBuilder: (context, index) {
                final cat = _categorias[index];
                final color = Color(int.parse(cat['Cor_Hexadecimal'].replaceAll('#', '0xFF')));
                
                IconData tipoIcon;
                Color tipoColor;
                if (cat['Tipo'] == 'Receita') {
                  tipoIcon = Icons.arrow_upward;
                  tipoColor = Colors.green;
                } else if (cat['Tipo'] == 'Despesa') {
                  tipoIcon = Icons.arrow_downward;
                  tipoColor = Colors.red;
                } else {
                  tipoIcon = Icons.compare_arrows;
                  tipoColor = Colors.blueGrey;
                }

                return Card(
                  key: ValueKey(cat['ID']),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: color),
                    title: Text(cat['Nome']),
                    subtitle: Row(
                      children: [
                        Icon(tipoIcon, size: 14, color: tipoColor),
                        const SizedBox(width: 4),
                        Text(cat['Tipo'] ?? 'Ambas', style: TextStyle(color: tipoColor)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCategory(cat['ID']),
                        ),
                        const Icon(Icons.drag_handle, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

