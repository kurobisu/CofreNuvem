import 'package:flutter/material.dart';
import '../database/supabase_helper.dart';
import '../utils/bancos_brasil.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/app_colors.dart';
import '../utils/tutorial_keys.dart';
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

  Future<void> _addMetodo(String nome, String contaId, String tipo, String? fechamento, String? vencimento, double? limite) async {
    final supabase = SupabaseHelper.instance.client;
    final maxOrdem = _metodos.where((m) => (m['conta_id'] ?? m['Conta_ID'])?.toString() == contaId).length;
    final Map<String, dynamic> data = {
      'nome': nome,
      'conta_id': contaId,
      'tipo': tipo,
      'ordem': maxOrdem,
      'dia_fechamento': fechamento,
      'dia_vencimento': vencimento,
      'limite_credito': limite,
      'auth_id': supabase.auth.currentUser?.id,
    };
    try {
      await supabase.from('metodos_pagamento').insert(data);
    } catch (e) {
      debugPrint('Erro ao inserir com limite_credito: $e, tentando sem o campo');
      data.remove('limite_credito');
      await supabase.from('metodos_pagamento').insert(data);
    }
    _loadData();
  }

  Future<void> _editMetodo(String metodoId, String nome, String? fechamento, String? vencimento, double? limite) async {
    final supabase = SupabaseHelper.instance.client;
    final Map<String, dynamic> data = {
      'nome': nome,
      'dia_fechamento': fechamento,
      'dia_vencimento': vencimento,
      'limite_credito': limite,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      await supabase.from('metodos_pagamento').update(data).eq('id', metodoId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Método e limite atualizados com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Erro ao atualizar limite_credito no Supabase: $e');
      data.remove('limite_credito');
      try {
        await supabase.from('metodos_pagamento').update(data).eq('id', metodoId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Aviso: Coluna limite_credito ainda não existe no banco Supabase remoto. Dados básicos salvos.'), backgroundColor: Colors.orange),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar: $err'), backgroundColor: Colors.red),
          );
        }
      }
    }
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

  Future<void> _deleteConta(String id, String nomeConta) async {
    // Confirmação 1: Alerta Crítico
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text('Excluir Conta?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Você tem certeza que deseja excluir a conta "$nomeConta"? Todos os métodos vinculados a ela serão afetados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, continuar'),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;

    // Confirmação 2: Confirmação definitiva com digitação do nome ou aviso severo
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.red, width: 2)),
        title: const Row(
          children: [
            Icon(Icons.dangerous, color: Colors.red, size: 30),
            SizedBox(width: 8),
            Expanded(child: Text('ATENÇÃO: AÇÃO IRREVERSÍVEL', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: Text(
          'Esta ação removerá permanentemente a conta "$nomeConta" e seus métodos de pagamento do banco de dados na nuvem.\n\nTem absoluta certeza de que deseja apagar?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: Colors.white))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CONFIRMAR EXCLUSÃO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm2 != true) return;

    final db = await SupabaseHelper.instance.database;
    await db.delete(SupabaseHelper.tableContasBancarias, where: 'ID = ?', whereArgs: [id]);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conta "$nomeConta" excluída com sucesso.')),
      );
    }
  }

  Future<void> _deleteMetodo(String id, String nomeMetodo) async {
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Excluir Método?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Deseja excluir o método de pagamento "$nomeMetodo"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;

    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.red, width: 2)),
        title: const Row(
          children: [
            Icon(Icons.dangerous, color: Colors.red, size: 30),
            SizedBox(width: 8),
            Text('Confirmar Exclusão', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'O método "$nomeMetodo" não estará mais disponível para novas transações.\n\nDeseja realmente apagá-lo?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('EXCLUIR MÉTODO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm2 != true) return;

    final db = await SupabaseHelper.instance.database;
    await db.delete(SupabaseHelper.tableMetodosPagamento, where: 'ID = ?', whereArgs: [id]);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Método "$nomeMetodo" excluído.')),
      );
    }
  }

  void _showAddContaDialog() {
    final nomeController = TextEditingController();
    BancoLogo? selectedBanco;
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
                      decoration: const InputDecoration(
                        labelText: 'Nome ou Apelido da Conta',
                        hintText: 'Ex: Nubank, Carteira, Dinheiro',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    Autocomplete<BancoLogo>(
                      displayStringForOption: (banco) => '${banco.codigo} - ${banco.nome}',
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return BancosBrasil.bancos;
                        }
                        return BancosBrasil.bancos.where((BancoLogo banco) {
                          return banco.nome.toLowerCase().contains(textEditingValue.text.toLowerCase()) || 
                                 banco.codigo.contains(textEditingValue.text);
                        });
                      },
                      onSelected: (BancoLogo selection) {
                        setStateDialog(() {
                          selectedBanco = selection;
                          if (nomeController.text.isEmpty) {
                            nomeController.text = selection.codigo == '100' ? 'Dinheiro' : selection.nome;
                          }
                        });
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Instituição / Tipo',
                            hintText: 'Selecione o banco ou Dinheiro Físico',
                            suffixIcon: selectedBanco != null 
                                ? Icon(selectedBanco!.iconData ?? Icons.account_balance, color: AppTheme.primary)
                                : null,
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
                    final nome = nomeController.text.trim();
                    if (nome.isNotEmpty && selectedDono != null) {
                      String codigo = selectedBanco?.codigo ?? '999';
                      if (nome.toLowerCase().contains('dinheiro') || nome.toLowerCase().contains('carteira') || nome.toLowerCase().contains('espécie')) {
                        codigo = '100';
                      }
                      _addConta(nome, codigo, selectedDono!);
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
    final limiteController = TextEditingController();
    String tipoSelecionado = opcoesDisponiveis.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Novo Método para $contaNome'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome (Ex: Nubank, Cartão Black)'),
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
                      TextField(
                        controller: limiteController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Limite Total do Cartão (R\$)',
                          hintText: 'Ex: 5000.00',
                          prefixText: 'R\$ ',
                        ),
                      ),
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
                      double? limite = tipoSelecionado == 'Crédito' 
                          ? double.tryParse(limiteController.text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim()) 
                          : null;
                      
                      _addMetodo(nomeController.text.trim(), contaId, tipoSelecionado, fechamento, vencimento, limite);
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

  void _showEditMetodoDialog(Map<String, dynamic> metodo) {
    final nomeController = TextEditingController(text: (metodo['Nome'] ?? metodo['nome'] ?? '').toString());
    final fechamentoController = TextEditingController(text: (metodo['Dia_Fechamento'] ?? metodo['dia_fechamento'] ?? '').toString());
    final vencimentoController = TextEditingController(text: (metodo['Dia_Vencimento'] ?? metodo['dia_vencimento'] ?? '').toString());
    final limiteRaw = metodo['limite_credito'] ?? metodo['Limite_Credito'];
    final limiteController = TextEditingController(text: limiteRaw != null ? limiteRaw.toString() : '');
    final isCredito = metodo['Tipo'] == 'Crédito' || metodo['tipo'] == 'Crédito';
    final metodoId = (metodo['ID'] ?? metodo['id']).toString();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Editar ${metodo['Nome'] ?? metodo['nome']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome do Método'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    if (isCredito) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: limiteController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Limite do Cartão (R\$)',
                          hintText: 'Ex: 5000.00',
                          prefixText: 'R\$ ',
                        ),
                      ),
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
                      String? fechamento = isCredito ? (fechamentoController.text.isNotEmpty ? fechamentoController.text : null) : null;
                      String? vencimento = isCredito ? (vencimentoController.text.isNotEmpty ? vencimentoController.text : null) : null;
                      double? limite = isCredito 
                          ? double.tryParse(limiteController.text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim()) 
                          : null;
                      
                      _editMetodo(metodoId, nomeController.text.trim(), fechamento, vencimento, limite);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                  child: const Text('Salvar Alterações'),
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
                        Icon(Icons.drag_handle, color: AppColors.iconMuted(context)),
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
                      onPressed: () => _deleteConta(contaId, conta['Nome']?.toString() ?? 'Sem Nome'),
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
                        final limite = m['limite_credito'] ?? m['Limite_Credito'];
                        final limiteStr = limite != null ? ' • Limite: ${CurrencyFormatter.format((limite as num).toDouble())}' : '';

                        return ListTile(
                          title: Text(m['Nome']),
                          subtitle: isCredito 
                            ? Text('Vencimento dia ${m['Dia_Vencimento']} (Fecha dia ${m['Dia_Fechamento']})$limiteStr', style: const TextStyle(fontSize: 12)) 
                            : Text(m['Tipo'] ?? 'Outros', style: const TextStyle(fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (index > 0)
                                IconButton(
                                   icon: Icon(Icons.arrow_upward, color: AppColors.iconMuted(context), size: 20),
                                  onPressed: () => _moveMetodo(contaId, index, index - 1),
                                ),
                              if (index < metodosDaConta.length - 1)
                                IconButton(
                                  icon: Icon(Icons.arrow_downward, color: AppColors.iconMuted(context), size: 20),
                                  onPressed: () => _moveMetodo(contaId, index, index + 1),
                                ),
                              if (isCredito)
                                IconButton(
                                  icon: const Icon(Icons.receipt_long, color: Colors.blue),
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoicesScreen(metodo: m))),
                                  tooltip: 'Ver Faturas',
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                onPressed: () => _showEditMetodoDialog(m),
                                tooltip: 'Editar Método / Limite',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _deleteMetodo(m['ID']?.toString() ?? m['id']?.toString() ?? '', m['Nome']?.toString() ?? 'Sem Nome'),
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
        key: TutorialKeys.accountsAddFab,
        onPressed: _showAddContaDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova Conta', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
