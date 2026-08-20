import 'package:flutter/material.dart';
import '../database/supabase_helper.dart';
import '../theme/app_theme.dart';
import '../utils/app_colors.dart';
import '../utils/tutorial_keys.dart';
import '../utils/tutorial_content.dart';
import '../widgets/tutorial_button.dart';

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(
                    user == null ? Icons.person_add_rounded : Icons.edit_rounded,
                    color: isFantasma ? Colors.purpleAccent : AppTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      user == null ? 'Novo Usuário' : 'Editar Usuário',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nomeController,
                        decoration: InputDecoration(
                          labelText: 'Nome do Usuário',
                          hintText: 'Ex: João Silva',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isFantasma 
                              ? Colors.purpleAccent.withOpacity(0.12)
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isFantasma
                                ? Colors.purpleAccent.withOpacity(0.5)
                                : AppColors.divider(context),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.visibility_off, size: 20, color: Colors.purpleAccent),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Usuário de Gestão',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                Switch(
                                  value: isFantasma,
                                  activeColor: Colors.purpleAccent,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      isFantasma = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Use para representar um membro da família que não vai fazer login sozinho (ex: filho, dependente ou um cofre conjunto). As transações e contas dele ficam visíveis para toda a família, mas ele não tem conta própria no app.',
                              style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context)),
                            ),
                          ],
                        ),
                      ),
                      if (!isFantasma) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: pinController,
                          decoration: InputDecoration(
                            labelText: 'PIN de Acesso (Opcional)',
                            hintText: '4 a 6 dígitos numéricos',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                          ),
                          keyboardType: TextInputType.number,
                          obscureText: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: AppColors.secondaryText(context))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final nome = nomeController.text.trim();
                    final pin = isFantasma ? 'FANTASMA' : pinController.text.trim();
                    
                    if (nome.isEmpty) return;
                    
                    try {
                      final db = await SupabaseHelper.instance.database;
                      
                      if (user == null) {
                        final maxOrdem = _users.isEmpty ? 0 : _users.length;
                        final Map<String, Object?> data = {
                          'Nome': nome,
                          'PIN_Acesso': pin,
                          'Ordem': maxOrdem,
                        };
                        dynamic newUserId;
                        try {
                          newUserId = await db.insert(SupabaseHelper.tableUsuarios, {
                            ...data,
                            'is_fantasma': isFantasma,
                          });
                        } catch (e) {
                          // Se a coluna is_fantasma não existir ainda no Supabase, salva normalmente
                          newUserId = await db.insert(SupabaseHelper.tableUsuarios, data);
                        }

                        // Criar automaticamente a Conta 'Dinheiro' com método 'Dinheiro' para o novo usuário
                        if (newUserId != null) {
                          try {
                            final allContas = await db.query(SupabaseHelper.tableContasBancarias);
                            final contaId = await db.insert(SupabaseHelper.tableContasBancarias, {
                              'Nome': 'Dinheiro',
                              'Codigo_Banco': '100', // Dinheiro Físico/Caixa
                              'Usuario_ID': newUserId.toString(),
                              'Ordem': allContas.length,
                            });
                            await db.insert(SupabaseHelper.tableMetodosPagamento, {
                              'Conta_ID': contaId.toString(),
                              'Nome': 'Dinheiro',
                              'Tipo': 'Dinheiro',
                              'Ordem': 0,
                            });
                          } catch (err) {
                            debugPrint('Erro ao criar conta Dinheiro automática: $err');
                          }
                        }
                      } else {
                        final Map<String, Object?> data = {
                          'Nome': nome, 
                          'PIN_Acesso': pin,
                        };
                        try {
                          await db.update(
                            SupabaseHelper.tableUsuarios,
                            {
                              ...data,
                              'is_fantasma': isFantasma,
                            },
                            where: 'ID = ?',
                            whereArgs: [user['id'] ?? user['ID']],
                          );
                        } catch (e) {
                          await db.update(
                            SupabaseHelper.tableUsuarios,
                            data,
                            where: 'ID = ?',
                            whereArgs: [user['id'] ?? user['ID']],
                          );
                        }
                      }
                      
                      if (context.mounted) Navigator.pop(context);
                      _loadUsers();
                    } catch (e) {
                      debugPrint('Erro ao salvar usuário: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFantasma ? Colors.purpleAccent : AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _deleteUser(String id, String nomeUser) async {
    final db = await SupabaseHelper.instance.database;
    
    // ETAPA 1 DE 3: Alerta inicial e verificação de dados vinculados
    final accounts = await db.query(SupabaseHelper.tableContasBancarias, where: 'usuario_id = ?', whereArgs: [id]);
    final trans = await db.query(SupabaseHelper.tableTransacoes, where: 'usuario_id = ?', whereArgs: [id]);
    
    if (accounts.isNotEmpty || trans.isNotEmpty) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Exclusão Bloqueada'),
            ],
          ),
          content: Text(
            'O usuário "$nomeUser" possui ${accounts.length} conta(s) e ${trans.length} transação(ões) vinculadas no sistema.\n\nPara segurança do histórico financeiro familiar, você deve transferir ou apagar as transações e contas antes de excluir este usuário.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            )
          ],
        ),
      );
      return;
    }

    // TELA 1 DE CONFIRMAÇÃO (Grave):
    final etapa1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text('Excluir Usuário "$nomeUser"? (1/3)', style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text('Você iniciou o processo de exclusão do usuário "$nomeUser".\n\nEste procedimento requer 3 etapas de segurança.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Avançar (Etapa 2)'),
          ),
        ],
      ),
    );

    if (etapa1 != true) return;

    // TELA 2 DE CONFIRMAÇÃO (Crítica):
    final etapa2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent, width: 2)),
        title: const Row(
          children: [
            Icon(Icons.report_problem, color: Colors.redAccent, size: 30),
            SizedBox(width: 8),
            Expanded(child: Text('CONFIRMAÇÃO CRÍTICA (2/3)', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: Text(
          'ATENÇÃO: A exclusão de um usuário apagará definitivamente o perfil de "$nomeUser" e qualquer permissão familiar associada.\n\nEsta operação é 100% permanente e não pode ser desfeita.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: Colors.white))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CONTINUAR PARA ETAPA FINAL'),
          ),
        ],
      ),
    );

    if (etapa2 != true) return;

    // TELA 3 DE CONFIRMAÇÃO (Digitação do Nome para confirmação final e definitiva):
    final digitacaoController = TextEditingController();
    final etapa3 = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isMatch = digitacaoController.text.trim().toLowerCase() == nomeUser.trim().toLowerCase();
            return AlertDialog(
              backgroundColor: const Color(0xFF130909),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.red, width: 2.5)),
              title: const Row(
                children: [
                  Icon(Icons.dangerous, color: Colors.red, size: 32),
                  SizedBox(width: 8),
                  Expanded(child: Text('AUTORIZAÇÃO DEFINITIVA (3/3)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Para confirmar a destruição permanente do usuário "$nomeUser", digite o nome exatamente como exibido abaixo:',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text(nomeUser, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: digitacaoController,
                    style: TextStyle(color: AppColors.onSurface(context)),
                    decoration: InputDecoration(
                      hintText: 'Digite o nome aqui',
                      hintStyle: TextStyle(color: AppColors.mutedText(context)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('CANCELAR', style: TextStyle(color: AppColors.onSurface(context)))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMatch ? Colors.red : AppColors.mutedText(context),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isMatch ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('EXCLUIR PERMANENTEMENTE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (etapa3 != true) return;

    await db.delete(SupabaseHelper.tableUsuarios, where: 'ID = ?', whereArgs: [id]);
    _loadUsers();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuário "$nomeUser" foi excluído com sucesso.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Usuários'),
        actions: const [TutorialButton(screen: TutorialScreens.usuarios)],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ReorderableListView.builder(
            onReorder: _onReorder,
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              final nome = user['nome'] ?? user['Nome'] ?? '?';
              final pin = user['pin_acesso'] ?? user['PIN_Acesso'];
              final isFantasma = (user['is_fantasma'] == 1 || user['is_fantasma'] == true || user['Is_Fantasma'] == 1 || user['Is_Fantasma'] == true || pin == 'FANTASMA');
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
                      onPressed: () => _deleteUser(id.toString(), nome.toString()),
                    ),
                    Icon(Icons.drag_handle, color: AppColors.iconMuted(context)),
                  ],
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        key: TutorialKeys.usuariosAddButton,
        onPressed: () => _showUserDialog(),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
