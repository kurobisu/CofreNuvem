import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/bancos_brasil.dart';
import '../theme/app_theme.dart';

class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({super.key});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  List<Map<String, dynamic>> _contas = [];
  List<Map<String, dynamic>> _metodos = [];
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _compartilhadas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    final contas = await db.query(DatabaseHelper.tableContasBancarias, orderBy: 'Ordem ASC');
    final metodos = await db.query(DatabaseHelper.tableMetodosPagamento);
    final usuarios = await db.query(DatabaseHelper.tableUsuarios);
    final comp = await db.query(DatabaseHelper.tableContasCompartilhadas);

    setState(() {
      _contas = List<Map<String, dynamic>>.from(contas);
      _metodos = metodos;
      _usuarios = usuarios;
      _compartilhadas = comp;
      _isLoading = false;
    });
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _contas.removeAt(oldIndex);
      _contas.insert(newIndex, item);
    });

    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    for (int i = 0; i < _contas.length; i++) {
      batch.update(DatabaseHelper.tableContasBancarias, {'Ordem': i}, where: 'ID = ?', whereArgs: [_contas[i]['ID']]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _addConta(String nome, String codigoBanco, int donoId) async {
    final db = await DatabaseHelper.instance.database;
    final maxOrdem = _contas.isEmpty ? 0 : _contas.length;
    await db.insert(DatabaseHelper.tableContasBancarias, {
      'Nome': nome,
      'Codigo_Banco': codigoBanco,
      'Usuario_ID': donoId,
      'Ordem': maxOrdem,
    });
    _loadData();
  }

  Future<void> _addMetodo(String nome, int contaId) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(DatabaseHelper.tableMetodosPagamento, {
      'Nome': nome,
      'Conta_ID': contaId,
    });
    _loadData();
  }

  Future<void> _compartilharConta(int contaId, int usuarioId) async {
    final db = await DatabaseHelper.instance.database;
    try {
      await db.insert(DatabaseHelper.tableContasCompartilhadas, {
        'Conta_ID': contaId,
        'Usuario_ID': usuarioId,
      });
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este usuário já tem acesso à conta.')),
        );
      }
    }
  }

  Future<void> _removerCompartilhamento(int contaId, int usuarioId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      DatabaseHelper.tableContasCompartilhadas,
      where: 'Conta_ID = ? AND Usuario_ID = ?',
      whereArgs: [contaId, usuarioId],
    );
    _loadData();
  }

  Future<void> _deleteConta(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableContasBancarias, where: 'ID = ?', whereArgs: [id]);
    _loadData();
  }

  Future<void> _deleteMetodo(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableMetodosPagamento, where: 'ID = ?', whereArgs: [id]);
    _loadData();
  }

  void _showAddContaDialog() {
    final nomeController = TextEditingController();
    BancoLogo selectedBanco = BancosBrasil.bancos.first;
    int? selectedDono = _usuarios.isNotEmpty ? _usuarios.first['ID'] as int : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Nova Conta Bancária'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome ou Apelido da Conta'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    Autocomplete<BancoLogo>(
                      displayStringForOption: (banco) => banco.codigo + ' - ' + banco.nome,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return BancosBrasil.bancos.take(10);
                        }
                        return BancosBrasil.bancos.where((BancoLogo banco) {
                          return banco.nome.toLowerCase().contains(textEditingValue.text.toLowerCase()) || 
                                 banco.codigo.contains(textEditingValue.text);
                        });
                      },
                      onSelected: (BancoLogo selection) {
                        setStateDialog(() => selectedBanco = selection);
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Buscar Banco',
                            hintText: 'Ex: Nubank, 001',
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedDono,
                      items: _usuarios.map((u) => DropdownMenuItem<int>(
                        value: u['ID'] as int,
                        child: Text(u['Nome']),
                      )).toList(),
                      onChanged: (val) => setStateDialog(() => selectedDono = val),
                      decoration: const InputDecoration(labelText: 'Dono da Conta'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (nomeController.text.trim().isNotEmpty && selectedDono != null) {
                      _addConta(nomeController.text.trim(), selectedBanco.codigo, selectedDono!);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                  child: const Text('Salvar'),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _showCompartilharDialog(int contaId, String contaNome) {
    int? selectedUsuario = _usuarios.isNotEmpty ? _usuarios.first['ID'] as int : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Compartilhar ' + contaNome),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Permitir que outro membro da família acesse e lance transações usando esta conta.', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedUsuario,
                    items: _usuarios.map((u) => DropdownMenuItem<int>(
                      value: u['ID'] as int,
                      child: Text(u['Nome']),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedUsuario = val),
                    decoration: const InputDecoration(labelText: 'Selecione o Usuário'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (selectedUsuario != null) {
                      _compartilharConta(contaId, selectedUsuario!);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Compartilhar'),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _showAddMetodoDialog(int contaId, String contaNome) {
    final nomeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Novo Método para ' + contaNome),
        content: TextField(
          controller: nomeController,
          decoration: const InputDecoration(labelText: 'Método (Ex: PIX, Crédito)'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (nomeController.text.trim().isNotEmpty) {
                _addMetodo(nomeController.text.trim(), contaId);
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          )
        ],
      )
    );
  }

  String _getUserName(int? id) {
    if (id == null) return 'Desconhecido';
    final match = _usuarios.where((u) => u['ID'] == id);
    if (match.isNotEmpty) return match.first['Nome'];
    return 'Desconhecido';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contas & Métodos')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              onReorder: _onReorder,
              padding: const EdgeInsets.all(16),
              itemCount: _contas.length,
              itemBuilder: (context, index) {
                final conta = _contas[index];
                final contaId = conta['ID'] as int;
                final metodosDaConta = _metodos.where((m) => m['Conta_ID'] == contaId).toList();
                
                final bancoCode = conta['Codigo_Banco']?.toString() ?? '999';
                final banco = BancosBrasil.obterBancoPorCodigo(bancoCode);
                final color = Color(int.parse(banco.colorHex.replaceAll('#', '0xFF')));

                final ownerName = _getUserName(conta['Usuario_ID'] as int?);
                final compAccess = _compartilhadas.where((c) => c['Conta_ID'] == contaId).toList();

                return Card(
                  key: ValueKey(contaId),
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ExpansionTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.drag_handle, color: Colors.grey),
                        const SizedBox(width: 8),
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                          child: Icon(banco.iconData ?? Icons.account_balance, color: Colors.white),
                        ),
                      ],
                    ),
                    title: Text(conta['Nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Dono: ' + ownerName),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteConta(contaId),
                    ),
                    children: [
                      const Divider(height: 1),
                      // Aba de Compartilhamento
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.grey.withOpacity(0.05),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Compartilhada com:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            if (compAccess.isEmpty) const Text('Somente o dono tem acesso.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Wrap(
                              spacing: 8,
                              children: compAccess.map((c) => Chip(
                                label: Text(_getUserName(c['Usuario_ID'] as int?)),
                                onDeleted: () => _removerCompartilhamento(contaId, c['Usuario_ID'] as int),
                              )).toList(),
                            ),
                            TextButton.icon(
                              onPressed: () => _showCompartilharDialog(contaId, conta['Nome']),
                              icon: const Icon(Icons.share, size: 16),
                              label: const Text('Compartilhar Conta'),
                            )
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Métodos de Pagamento
                      ...metodosDaConta.map((m) => ListTile(
                        title: Text(m['Nome']),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                          onPressed: () => _deleteMetodo(m['ID']),
                        ),
                      )).toList(),
                      ListTile(
                        leading: const Icon(Icons.add_circle, color: Colors.green),
                        title: const Text('Adicionar Método'),
                        onTap: () => _showAddMetodoDialog(contaId, conta['Nome']),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddContaDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova Conta', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
