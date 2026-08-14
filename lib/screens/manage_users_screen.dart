import 'package:flutter/material.dart';
import '../database/supabase_helper.dart';
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
    final db = await SupabaseHelper.instance.database;
    final List<Map<String, dynamic>> users = await db.query(SupabaseHelper.tableUsuarios, orderBy: 'Ordem ASC');
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

    final supabase = SupabaseHelper.instance.client;
    for (int i = 0; i < _users.length; i++) {
      final id = _users[i]['id'] ?? _users[i]['ID'];
      await supabase.from('usuarios').update({'ordem': i}).eq('id', id);
    }
  }

  void _showUserDialog([Map<String, dynamic>? user]) {
    final nomeController = TextEditingController(text: user?['nome'] ?? user?['Nome'] ?? '');
    final pinController = TextEditingController(text: user?['pin_acesso'] ?? user?['PIN_Acesso'] ?? '');
    bool isFantasma = (user?['is_fantasma'] == 1 || user?['is_fantasma'] == true || user?['Is_Fantasma'] == 1 || user?['Is_Fantasma'] == true);
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(user == null ? 'Novo Membro / Usuário' : 'Editar Usuário'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Usuário',
                        hintText: 'Ex: Filho, Casa de Praia, Reserva...',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Row(
                        children: [
                          Icon(Icons.visibility_off, size: 20, color: Colors.purpleAccent),
                          SizedBox(width: 8),
                          Text('Usuário de Gestão', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      subtitle: const Text(
                        'Usuário fantasma sem login/senha. Usado para gerenciar contas, gastos e cartões pela família.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: isFantasma,
                      onChanged: (val) {
                        setDialogState(() {
                          isFantasma = val;
                        });
                      },
                    ),
                    if (!isFantasma) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: pinController,
                        decoration: const InputDecoration(
                          labelText: 'PIN de Acesso (Opcional)',
                          hintText: '4 a 6 dígitos',
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final nome = nomeController.text.trim();
                    final pin = isFantasma ? '' : pinController.text.trim();
                    
                    if (nome.isEmpty) return;
                    
                    final db = await SupabaseHelper.instance.database;
                    
                    if (user == null) {
                      final maxOrdem = _users.isEmpty ? 0 : _users.length;
                      await db.insert(SupabaseHelper.tableUsuarios, {
                        'Nome': nome,
                        'PIN_Acesso': pin,
                        'Ordem': maxOrdem,
                        'is_fantasma': isFantasma ? 1 : 0,
                      });
                    } else {
                      await db.update(
                        SupabaseHelper.tableUsuarios,
                        {
                          'Nome': nome, 
                          'PIN_Acesso': pin,
                          'is_fantasma': isFantasma ? 1 : 0,
                        },
                        where: 'ID = ?',
                        whereArgs: [user['id'] ?? user['ID']],
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
          }
        );
      },
    );
  }

  void _deleteUser(String id) async {
    final db = await SupabaseHelper.instance.database;
    
    // Validate if the user can be deleted (maybe they have accounts or transactions)
    final accounts = await db.query(SupabaseHelper.tableContasBancarias, where: 'Usuario_ID = ?', whereArgs: [id]);
    final trans = await db.query(SupabaseHelper.tableTransacoes, where: 'Usuario_ID = ?', whereArgs: [id]);
    
    if (accounts.isNotEmpty || trans.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este usuário possui contas ou transações vinculadas e não pode ser apagado.')),
      );
      return;
    }

    await db.delete(SupabaseHelper.tableUsuarios, where: 'ID = ?', whereArgs: [id]);
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
              final nome = user['nome'] ?? user['Nome'] ?? '?';
              final pin = user['pin_acesso'] ?? user['PIN_Acesso'];
              final isFantasma = (user['is_fantasma'] == 1 || user['is_fantasma'] == true || user['Is_Fantasma'] == 1 || user['Is_Fantasma'] == true);
              final id = user['id'] ?? user['ID'];
              return ListTile(
                key: ValueKey(id),
                leading: CircleAvatar(
                  backgroundColor: isFantasma ? Colors.purpleAccent.withOpacity(0.2) : AppTheme.accent.withOpacity(0.2),
                  child: isFantasma
                    ? const Icon(Icons.visibility_off, color: Colors.purpleAccent, size: 20)
                    : Text(nome.isNotEmpty ? nome.substring(0, 1) : '?', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
                title: Row(
                  children: [
                    Text(nome),
                    if (isFantasma) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
                        ),
                        child: const Text('Gestão', style: TextStyle(fontSize: 10, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(isFantasma ? 'Usuário de Gestão (Família)' : (pin?.isNotEmpty == true ? 'Com PIN' : 'Sem restrição')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showUserDialog(user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteUser(id),
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
