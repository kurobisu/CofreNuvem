import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> users = await db.query(DatabaseHelper.tableUsuarios, orderBy: 'Ordem ASC');
    setState(() {
      _users = List<Map<String, dynamic>>.from(users); // Make modifiable
      _isLoading = false;
    });
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _users.removeAt(oldIndex);
      _users.insert(newIndex, item);
    });

    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    for (int i = 0; i < _users.length; i++) {
      batch.update(DatabaseHelper.tableUsuarios, {'Ordem': i}, where: 'ID = ?', whereArgs: [_users[i]['ID']]);
    }
    await batch.commit(noResult: true);
  }

  void _showUserDialog([Map<String, dynamic>? user]) {
    final nomeController = TextEditingController(text: user?['Nome'] ?? '');
    final pinController = TextEditingController(text: user?['PIN_Acesso'] ?? '');
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(user == null ? 'Novo Usuário' : 'Editar Usuário'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome do Membro'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                decoration: const InputDecoration(labelText: 'PIN de Acesso (Opcional)'),
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nome = nomeController.text.trim();
                final pin = pinController.text.trim();
                
                if (nome.isEmpty) return;
                
                final db = await DatabaseHelper.instance.database;
                
                if (user == null) {
                  // Determina a ordem para o final da lista
                  final maxOrdem = _users.isEmpty ? 0 : _users.length;
                  await db.insert(DatabaseHelper.tableUsuarios, {
                    'Nome': nome,
                    'PIN_Acesso': pin,
                    'Ordem': maxOrdem,
                  });
                } else {
                  await db.update(
                    DatabaseHelper.tableUsuarios,
                    {'Nome': nome, 'PIN_Acesso': pin},
                    where: 'ID = ?',
                    whereArgs: [user['ID']],
                  );
                }
                
                if (context.mounted) Navigator.pop(context);
                _loadUsers();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _deleteUser(int id) async {
    final db = await DatabaseHelper.instance.database;
    
    // Validate if the user can be deleted (maybe they have accounts or transactions)
    final accounts = await db.query(DatabaseHelper.tableContasBancarias, where: 'Usuario_ID = ?', whereArgs: [id]);
    final trans = await db.query(DatabaseHelper.tableTransacoes, where: 'Usuario_ID = ?', whereArgs: [id]);
    
    if (accounts.isNotEmpty || trans.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este usuário possui contas ou transações vinculadas e não pode ser apagado.')),
      );
      return;
    }

    await db.delete(DatabaseHelper.tableUsuarios, where: 'ID = ?', whereArgs: [id]);
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Usuários')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ReorderableListView.builder(
            onReorder: _onReorder,
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return ListTile(
                key: ValueKey(user['ID']),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.accent.withOpacity(0.2),
                  child: Text(user['Nome'].substring(0, 1), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
                title: Text(user['Nome']),
                subtitle: Text(user['PIN_Acesso']?.isNotEmpty == true ? 'Com PIN' : 'Sem restrição'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showUserDialog(user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteUser(user['ID']),
                    ),
                    const Icon(Icons.drag_handle, color: Colors.grey),
                  ],
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
