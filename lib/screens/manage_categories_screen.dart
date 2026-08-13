import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool _hasOrderChanges = false;
  bool _isSaving = false;
  StreamSubscription? _categoriaSubscription;

  // Local reorder caches — only written to DB on SALVAR
  Map<String, List<Map<String, dynamic>>> _localParentsByTab = {};
  Map<String, List<Map<String, dynamic>>> _localChildren = {};

  @override
  void initState() {
    super.initState();
    _loadCategorias();
  }

  @override
  void dispose() {
    _categoriaSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCategorias() async {
    await DefaultData.seedDefaultCategories();
    _categoriaSubscription?.cancel();
    _categoriaSubscription = Supabase.instance.client
        .from(SupabaseHelper.tableCategorias)
        .stream(primaryKey: ['id'])
        .order('ordem', ascending: true)
        .order('nome', ascending: true)
        .listen((data) {
      if (mounted) {
        setState(() {
          _categorias = data
              .where((c) => c['deleted_at'] == null && c['Deleted_At'] == null)
              .map((e) => CaseInsensitiveMap(e))
              .cast<Map<String, dynamic>>()
              .toList();
          _isLoading = false;
          // Reset local caches when remote data arrives (only if no pending changes)
          if (!_hasOrderChanges) {
            _localParentsByTab = {};
            _localChildren = {};
          }
        });
      }
    });
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
  }

  Future<void> _updateCategory(String id, String nome, String hexColor, String tipo, String? parentId) async {
    final db = await SupabaseHelper.instance.database;
    await db.update(SupabaseHelper.tableCategorias, {
      'Nome': nome,
      'Cor_Hexadecimal': hexColor,
      'Tipo': tipo,
      'Parent_ID': parentId,
    }, where: 'ID = ?', whereArgs: [id]);
  }

  Future<void> _saveAllOrders() async {
    if (!_hasOrderChanges) return;
    setState(() => _isSaving = true);

    try {
      final db = await SupabaseHelper.instance.database;

      // Save parent orders across all tabs
      for (final tabKey in _localParentsByTab.keys) {
        final parentList = _localParentsByTab[tabKey]!;
        debugPrint('Saving order for tab $tabKey with ${parentList.length} items');
        for (int i = 0; i < parentList.length; i++) {
          final id = parentList[i]['id'] ?? parentList[i]['ID'];
          debugPrint('Updating parent category $id to order $i');
          await db.update(SupabaseHelper.tableCategorias, {'Ordem': i},
              where: 'id = ?', whereArgs: [id]);
        }
      }

      // Save children orders
      for (final parentId in _localChildren.keys) {
        final childList = _localChildren[parentId]!;
        debugPrint('Saving order for children under parent $parentId with ${childList.length} items');
        for (int i = 0; i < childList.length; i++) {
          final id = childList[i]['id'] ?? childList[i]['ID'];
          debugPrint('Updating child category $id to order $i');
          await db.update(SupabaseHelper.tableCategorias, {'Ordem': i},
              where: 'id = ?', whereArgs: [id]);
        }
      }

      if (mounted) {
        setState(() {
          _hasOrderChanges = false;
          _isSaving = false;
          _localParentsByTab = {};
          _localChildren = {};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ordem salva com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao salvar ordens de categorias: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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
      // 2. Unlink transactions
      await db.update(SupabaseHelper.tableTransacoes, {'Categoria_ID': null}, where: 'Categoria_ID = ?', whereArgs: [id]);
      
      await db.delete(SupabaseHelper.tableCategorias, where: 'ID = ?', whereArgs: [id]);
    }
  }

  Future<void> _toggleOculta(String id, int atual) async {
    final db = await SupabaseHelper.instance.database;
    await db.update(SupabaseHelper.tableCategorias, {'Oculta': atual == 0 ? 1 : 0}, where: 'ID = ?', whereArgs: [id]);
  }

  // Neon glow proxy decorator for drag feedback
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final elevation = Tween<double>(begin: 0, end: 12).animate(animation).value;
        return Material(
          elevation: elevation,
          color: Colors.transparent,
          shadowColor: Colors.greenAccent.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.9), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  void _showCategoryDialog([Map<String, dynamic>? category, String? preselectedParent]) {
    final nomeController = TextEditingController(text: category?['Nome'] ?? '');
    String selectedColor = category?['Cor_Hexadecimal'] ?? '#2196F3';
    String selectedTipo = category?['Tipo'] ?? 'Despesa';
    String? selectedParentId = category?['Parent_ID']?.toString() ?? preselectedParent;

    final parents = _categorias.where((c) => c['Parent_ID'] == null).toList();

    final colors = ['#F44336','#E91E63','#9C27B0','#673AB7','#3F51B5','#2196F3','#03A9F4','#00BCD4','#009688','#4CAF50','#8BC34A','#CDDC39','#FFC107','#FF9800','#FF5722','#795548','#607D8B'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(category == null ? 'Nova Categoria' : 'Editar Categoria'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome da Categoria'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedTipo,
                      items: ['Receita', 'Despesa', 'Ambas'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setDialogState(() => selectedTipo = v!),
                      decoration: const InputDecoration(labelText: 'Tipo'),
                    ),
                    const SizedBox(height: 12),
                    if (preselectedParent == null)
                      DropdownButtonFormField<String?>(
                        value: selectedParentId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Nenhuma (Categoria Pai)')),
                          ...parents.map((p) => DropdownMenuItem(value: p['ID'].toString(), child: Text(p['Nome']))),
                        ],
                        onChanged: (v) => setDialogState(() => selectedParentId = v),
                        decoration: const InputDecoration(labelText: 'Categoria Pai'),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colors.map((color) {
                        final c = Color(int.parse(color.replaceAll('#', '0xFF')));
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = color),
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

  void _moveChildUp(String parentId, int index, List<Map<String, dynamic>> currentChildren) {
    if (index == 0) return;
    setState(() {
      final cList = List<Map<String, dynamic>>.from(currentChildren);
      final item = cList.removeAt(index);
      cList.insert(index - 1, item);
      _localChildren[parentId] = cList;
      _hasOrderChanges = true;
    });
  }

  void _moveChildDown(String parentId, int index, List<Map<String, dynamic>> currentChildren) {
    if (index >= currentChildren.length - 1) return;
    setState(() {
      final cList = List<Map<String, dynamic>>.from(currentChildren);
      final item = cList.removeAt(index);
      cList.insert(index + 1, item);
      _localChildren[parentId] = cList;
      _hasOrderChanges = true;
    });
  }

  Widget _buildCategoryList(String tabKey, List<Map<String, dynamic>> parents, List<Map<String, dynamic>> allCategories) {
    if (parents.isEmpty) {
      return const Center(child: Text('Nenhuma categoria encontrada.'));
    }

    // Use local cache if available, otherwise use the passed-in list
    final displayParents = _localParentsByTab[tabKey] ?? List<Map<String, dynamic>>.from(parents);

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.all(16).copyWith(bottom: 80),
      proxyDecorator: _proxyDecorator,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        setState(() {
          final pList = List<Map<String, dynamic>>.from(displayParents);
          final item = pList.removeAt(oldIndex);
          pList.insert(newIndex, item);
          _localParentsByTab[tabKey] = pList;
          _hasOrderChanges = true;
        });
      },
      itemCount: displayParents.length,
      itemBuilder: (context, index) {
        final parent = displayParents[index];
        final parentId = parent['ID'].toString();
        final dbChildren = allCategories.where((c) => c['Parent_ID'] == parent['ID']).toList();
        final children = _localChildren[parentId] ?? dbChildren;
        
        final parentColor = Color(int.parse(parent['Cor_Hexadecimal'].toString().replaceAll('#', '0xFF')));
        final isHidden = parent['Oculta'] == 1;

        return Card(
          key: ValueKey(parentId),
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    ReorderableDelayedDragStartListener(
                      index: index,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(backgroundColor: parentColor, radius: 14),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(parent['Nome'], style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, decoration: isHidden ? TextDecoration.lineThrough : null)),
                              Text(parent['Tipo'], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.add, color: Colors.green),
                          tooltip: 'Nova Sub-categoria',
                          onPressed: () => _showCategoryDialog(null, parentId),
                        ),
                        const SizedBox(width: 4),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: !isHidden,
                            onChanged: (val) => _toggleOculta(parentId, parent['Oculta']),
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
                Column(
                  children: children.asMap().entries.map((entry) {
                    final childIndex = entry.key;
                    final child = entry.value;
                    final childHidden = child['Oculta'] == 1;
                    return Padding(
                      key: ValueKey(child['ID'].toString()),
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
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                icon: const Icon(Icons.keyboard_arrow_up, color: Colors.grey, size: 20),
                                onPressed: childIndex > 0 ? () => _moveChildUp(parentId, childIndex, children) : null,
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
                                onPressed: childIndex < children.length - 1 ? () => _moveChildDown(parentId, childIndex, children) : null,
                              ),
                              const SizedBox(width: 4),
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
                  }).toList(),
                ),
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
    
    final uniqueReceitas = <String>{};
    final receitasParents = allParents.where((c) => (c['Tipo'] == 'Receita' || c['Tipo'] == 'Ambas') && uniqueReceitas.add(c['Nome'].toString())).toList();
    
    final uniqueMercado = <String>{};
    final mercadoParent = allParents.where((c) => c['Nome'] == 'Mercado' && uniqueMercado.add(c['Nome'].toString())).toList();
    
    final uniqueDespesas = <String>{};
    final despesasParents = allParents.where((c) => (c['Tipo'] == 'Despesa' || c['Tipo'] == 'Ambas') && c['Nome'] != 'Mercado' && uniqueDespesas.add(c['Nome'].toString())).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Categorias'),
              if (_hasOrderChanges) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAllOrders,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, size: 18),
                  label: Text(_isSaving ? 'Salvando...' : 'SALVAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 4,
                    shadowColor: Colors.greenAccent,
                  ),
                ),
              ],
            ],
          ),
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
            _buildCategoryList('receitas', receitasParents, _categorias),
            _buildCategoryList('despesas', despesasParents, _categorias),
            _buildCategoryList('mercado', mercadoParent, _categorias),
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
