import 'package:flutter/material.dart';
import '../database/supabase_helper.dart';
import '../utils/bancos_brasil.dart';
import '../theme/app_theme.dart';
import 'invoices_screen.dart';

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
    setState(() => _isLoading = true);
    final db = await SupabaseHelper.instance.database;
    final contas = await db.query(SupabaseHelper.tableContasBancarias, orderBy: 'Ordem ASC');
    final metodos = await db.query(SupabaseHelper.tableMetodosPagamento, orderBy: 'Ordem ASC');
    final usuarios = await db.query(SupabaseHelper.tableUsuarios);

    setState(() {
      _contas = contas;
      _metodos = metodos;
      _usuarios = usuarios;
      _isLoading = false;
    });
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _contas.removeAt(oldIndex);
      _contas.insert(newIndex, item);
    });

    final supabase = SupabaseHelper.instance.client;
    for (int i = 0; i < _contas.length; i++) {
      final id = _contas[i]['ID'] ?? _contas[i]['id'];
      await supabase.from('contas_bancarias').update({'ordem': i}).eq('id', id);
    }
  }

  Future<void> _addConta(String nome, String codigoBanco, String donoId) async {
    final db = await SupabaseHelper.instance.database;
    final maxOrdem = _contas.isEmpty ? 0 : _contas.length;
    final contaId = await db.insert(SupabaseHelper.tableContasBancarias, {
      'Nome': nome,
      'Codigo_Banco': codigoBanco,
      'Usuario_ID': donoId,
      'Ordem': maxOrdem,
    });

    if (codigoBanco != '100') {
      await db.insert(SupabaseHelper.tableMetodosPagamento, {
        'Conta_ID': contaId,
        'Nome': 'PIX',
        'Tipo': 'PIX',
        'Ordem': 0,
      });
      await db.insert(SupabaseHelper.tableMetodosPagamento, {
        'Conta_ID': contaId,
        'Nome': 'Cartão de Débito',
        'Tipo': 'Débito',
        'Ordem': 1,
      });
    } else {
      await db.insert(SupabaseHelper.tableMetodosPagamento, {
        'Conta_ID': contaId,
        'Nome': 'Dinheiro',
        'Tipo': 'Dinheiro',
        'Ordem': 0,
      });
    }

    _loadData();
  }

  Future<void> _addMetodo(String nome, String contaId, String tipo, String? fechamento, String? vencimento) async {
    final db = await SupabaseHelper.instance.database;
    final maxOrdem = _metodos.where((m) => m['Conta_ID'] == contaId).length;
    await db.insert(SupabaseHelper.tableMetodosPagamento, {
      'Nome': nome,
      'Conta_ID': contaId,
      'Tipo': tipo,
      'Ordem': maxOrdem,
      'Dia_Fechamento': fechamento,
      'Dia_Vencimento': vencimento,
    });
    _loadData();
  }

  Future<void> _moveMetodo(String contaId, int oldIndex, int newIndex) async {
    final metodosDaConta = _metodos.where((m) => m['Conta_ID'] == contaId).toList();
    if (oldIndex < 0 || oldIndex >= metodosDaConta.length || newIndex < 0 || newIndex >= metodosDaConta.length) return;

    final item = metodosDaConta.removeAt(oldIndex);
    metodosDaConta.insert(newIndex, item);

    final supabase = SupabaseHelper.instance.client;
    for (int i = 0; i < metodosDaConta.length; i++) {
      final id = metodosDaConta[i]['ID'] ?? metodosDaConta[i]['id'];
      await supabase.from('metodos_pagamento').update({'ordem': i}).eq('id', id);
    }
    _loadData();
  }

  Future<void> _compartilharConta(String contaId, String usuarioId) async {
    // Compartilhamento agora é global (Familia)
    // if (_selectedUserIds.isNotEmpty) {
    //   for (var uid in _selectedUserIds) {
    //     await db.insert(SupabaseHelper.tableContasCompartilhadas, {
    //       'Conta_ID': cId,
    //       'Usuario_ID': uid
    //     });
    //   }
    // }
  }

  Future<void> _removerCompartilhamento(String contaId, String usuarioId) async {
    // Compartilhamento agora é global
  }

  Future<void> _deleteConta(String id) async {
    final db = await SupabaseHelper.instance.database;
    await db.delete(SupabaseHelper.tableContasBancarias, where: 'ID = ?', whereArgs: [id]);
    _loadData();
  }

  Future<void> _deleteMetodo(String id) async {
    final db = await SupabaseHelper.instance.database;
    await db.delete(SupabaseHelper.tableMetodosPagamento, where: 'ID = ?', whereArgs: [id]);
    _loadData();
  }

  void _showAddContaDialog() {
    final nomeController = TextEditingController();
    BancoLogo selectedBanco = BancosBrasil.bancos.first;
    String? selectedDono = _usuarios.isNotEmpty ? _usuarios.first['ID'].toString() : null;

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
                    DropdownButtonFormField<String>(
                      value: selectedDono,
                      items: _usuarios.map((u) => DropdownMenuItem<String>(
                        value: u['ID'].toString(),
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

  void _showCompartilharDialog(String contaId, String contaNome) {
    String? selectedUsuario = _usuarios.isNotEmpty ? _usuarios.first['ID'].toString() : null;

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
                  DropdownButtonFormField<String>(
                    value: selectedUsuario,
                    items: _usuarios.map((u) => DropdownMenuItem<String>(
                      value: u['ID'].toString(),
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

  void _showAddMetodoDialog(String contaId, String contaNome) {
    final metodosDaConta = _metodos.where((m) => m['Conta_ID'] == contaId).toList();
    List<String> opcoesDisponiveis = ['Outros'];
    
    if (!metodosDaConta.any((m) => m['Tipo'] == 'PIX')) opcoesDisponiveis.insert(0, 'PIX');
    if (!metodosDaConta.any((m) => m['Tipo'] == 'Débito')) opcoesDisponiveis.insert(0, 'Débito');
    if (!metodosDaConta.any((m) => m['Tipo'] == 'Crédito')) opcoesDisponiveis.insert(0, 'Crédito');
    if (!metodosDaConta.any((m) => m['Tipo'] == 'Dinheiro')) opcoesDisponiveis.insert(0, 'Dinheiro');

    final nomeController = TextEditingController(text: opcoesDisponiveis.first != 'Outros' ? opcoesDisponiveis.first : '');
    final fechamentoController = TextEditingController();
    final vencimentoController = TextEditingController();
    String tipoSelecionado = opcoesDisponiveis.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Novo Método para ' + contaNome),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome (Ex: Nubank, Vale Refeição)'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: tipoSelecionado,
                      items: opcoesDisponiveis.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          tipoSelecionado = val!;
                          if (val != 'Outros') nomeController.text = val;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Tipo de Método'),
                    ),
                    if (tipoSelecionado == 'Crédito') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: fechamentoController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Dia Fechamento'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: vencimentoController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Dia Vencimento'),
                            ),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (nomeController.text.trim().isNotEmpty) {
                      String? fechamento = tipoSelecionado == 'Crédito' ? (fechamentoController.text.isNotEmpty ? fechamentoController.text : null) : null;
                      String? vencimento = tipoSelecionado == 'Crédito' ? (vencimentoController.text.isNotEmpty ? vencimentoController.text : null) : null;
                      
                      _addMetodo(nomeController.text.trim(), contaId, tipoSelecionado, fechamento, vencimento);
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

  String _getUserName(String? id) {
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
                final contaId = conta['ID'].toString();
                final metodosDaConta = _metodos.where((m) => m['Conta_ID'] == contaId).toList();
                
                final bancoCode = conta['Codigo_Banco']?.toString() ?? '999';
                final banco = BancosBrasil.obterBancoPorCodigo(bancoCode);
                final color = Color(int.parse(banco.colorHex.replaceAll('#', '0xFF')));

                final ownerName = _getUserName(conta['Usuario_ID']?.toString());

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
                      // Compartilhamento global
                      // await db.delete(SupabaseHelper.tableContasCompartilhadas, where: 'Conta_ID = ?', whereArgs: [widget.accountToEdit!['ID']]);
                      // if (_selectedUserIds.isNotEmpty) {
                      //   for (var uid in _selectedUserIds) {
                      //     await db.insert(SupabaseHelper.tableContasCompartilhadas, {
                      //       'Conta_ID': widget.accountToEdit!['ID'],
                      //       'Usuario_ID': uid
                      //     });
                      //   }
                      // }
                      const Divider(height: 1),
                      // Métodos de Pagamento
                      ...metodosDaConta.asMap().entries.map((entry) {
                        int index = entry.key;
                        var m = entry.value;
                        bool isCredito = m['Tipo'] == 'Crédito';
                        return ListTile(
                          title: Text(m['Nome']),
                          subtitle: isCredito 
                            ? Text('Vencimento dia ${m['Dia_Vencimento']} (Fecha dia ${m['Dia_Fechamento']})', style: const TextStyle(fontSize: 12)) 
                            : Text(m['Tipo'] ?? 'Outros', style: const TextStyle(fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (index > 0)
                                IconButton(
                                  icon: const Icon(Icons.arrow_upward, color: Colors.grey, size: 20),
                                  onPressed: () => _moveMetodo(contaId, index, index - 1),
                                ),
                              if (index < metodosDaConta.length - 1)
                                IconButton(
                                  icon: const Icon(Icons.arrow_downward, color: Colors.grey, size: 20),
                                  onPressed: () => _moveMetodo(contaId, index, index + 1),
                                ),
                              if (isCredito)
                                IconButton(
                                  icon: const Icon(Icons.receipt_long, color: Colors.blue),
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoicesScreen(metodo: m))),
                                  tooltip: 'Ver Faturas',
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _deleteMetodo(m['ID']),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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
