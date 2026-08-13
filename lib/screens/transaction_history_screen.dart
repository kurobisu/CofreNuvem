import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/supabase_helper.dart';
import '../utils/currency_formatter.dart';
import '../utils/transaction_helper.dart';
import '../utils/bancos_brasil.dart';
import 'transaction_form_screen.dart';
import 'family_transfer_screen.dart';
import '../providers/dashboard_provider.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  // Filtros
  String _searchQuery = '';
  String? _filterMonth; 
  String _filterStatus = 'Todos'; // 'Todos', 'Pagas', 'Pendentes'
  String _sortOrder = 't.Data DESC'; // 't.Data DESC', 't.Valor DESC'

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final supabase = SupabaseHelper.instance.client;
      
      // Buscar transações
      var query = supabase
          .from('transacoes')
          .select('*, categorias(nome, cor_hexadecimal), contas_bancarias(nome, codigo_banco), metodos_pagamento(nome), usuarios(nome)')
          .filter('deleted_at', 'is', null);
          
      final List<dynamic> response = await query;
      List<Map<String, dynamic>> result = [];
      
      final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();

      for (var row in response) {
        // Envolver a linha principal em CaseInsensitiveMap
        final t = CaseInsensitiveMap(row as Map<String, dynamic>);
        
        // Aplicar Status
        final paga = t['Paga'] ?? t['paga'];
        if (_filterStatus == 'Pagas' && paga != 1 && paga != true) continue;
        if (_filterStatus == 'Pendentes' && paga != 0 && paga != false) continue;
        
        // Data efetiva (COALESCE)
        String dataEfetiva = (t['Data_Fatura'] ?? t['data_fatura'] ?? t['Data'] ?? t['data'] ?? '').toString();
        
        // Aplicar Mês
        if (_filterMonth != null) {
          if (!dataEfetiva.startsWith(_filterMonth!)) continue;
        } else {
          if (dataEfetiva.isNotEmpty && dataEfetiva.compareTo(ninetyDaysAgo) < 0) continue;
        }
        
        final catMap = t['categorias'] != null ? CaseInsensitiveMap(t['categorias'] as Map<String, dynamic>) : null;
        final contaMap = t['contas_bancarias'] != null ? CaseInsensitiveMap(t['contas_bancarias'] as Map<String, dynamic>) : null;
        final metMap = t['metodos_pagamento'] != null ? CaseInsensitiveMap(t['metodos_pagamento'] as Map<String, dynamic>) : null;
        final userMap = t['usuarios'] != null ? CaseInsensitiveMap(t['usuarios'] as Map<String, dynamic>) : null;

        // Aplicar Busca
        if (_searchQuery.isNotEmpty) {
          final desc = (t['Descricao'] ?? t['descricao'] ?? '').toString().toLowerCase();
          final cat = (catMap?['nome'] ?? catMap?['Nome'] ?? '').toString().toLowerCase();
          final val = (t['Valor'] ?? t['valor'] ?? '').toString().toLowerCase();
          final q = _searchQuery.toLowerCase();
          if (!desc.contains(q) && !cat.contains(q) && !val.contains(q)) {
            continue;
          }
        }
        
        // Mapear relacionamentos para o formato antigo esperado pela UI
        t['CategoriaNome'] = catMap?['nome'] ?? catMap?['Nome'] ?? 'Sem Categoria';
        t['Cor_Hexadecimal'] = catMap?['cor_hexadecimal'] ?? catMap?['Cor_Hexadecimal'] ?? '#9E9E9E';
        t['Codigo_Banco'] = contaMap?['codigo_banco'] ?? contaMap?['Codigo_Banco'] ?? '';
        t['ContaNome'] = contaMap?['nome'] ?? contaMap?['Nome'] ?? 'Sem Conta';
        t['MetodoNome'] = metMap?['nome'] ?? metMap?['Nome'] ?? ((t['transferencia_id'] ?? t['Transferencia_ID']) != null ? 'PIX' : 'N/A');
        t['UsuarioNome'] = userMap?['nome'] ?? userMap?['Nome'] ?? 'N/A';
        t['HasItems'] = 0; 
        
        result.add(t);
      }

      // Ordenação
      if (_sortOrder == 't.Data DESC') {
        result.sort((a, b) => (b['Data'] ?? b['data'] ?? '').toString().compareTo((a['Data'] ?? a['data'] ?? '').toString()));
      } else if (_sortOrder == 't.Data ASC') {
        result.sort((a, b) => (a['Data'] ?? a['data'] ?? '').toString().compareTo((b['Data'] ?? b['data'] ?? '').toString()));
      } else if (_sortOrder == 't.Valor DESC') {
        result.sort((a, b) => ((b['Valor'] ?? b['valor'] ?? 0) as num).toDouble().compareTo(((a['Valor'] ?? a['valor'] ?? 0) as num).toDouble()));
      }

      setState(() {
        _transactions = result;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('Erro ao carregar transações: $e');
      debugPrint(stack.toString());
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePagaStatus(String id, int currentStatus) async {
    await SupabaseHelper.instance.client.from('transacoes').update({'Paga': currentStatus == 1 ? 0 : 1}).eq('id', id);
    _loadTransactions();
    ref.refresh(dashboardDataProvider);
  }

  Future<void> _deleteTransaction(String id) async {
    await TransactionHelper.deleteTransactionWithConfirmation(context, id, ref, () {
      _loadTransactions();
      ref.refresh(dashboardDataProvider);
    });
  }

  void _showTransactionOptions(Map<String, dynamic> t) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bottomSheetContext) {
        final transferId = t['transferencia_id'] ?? t['Transferencia_ID'];
        final isTransfer = transferId != null && transferId.toString().isNotEmpty && transferId.toString() != 'null';

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(t['Descricao'] ?? t['descricao'] ?? 'Sem Descrição', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Text('Opções da Transação', style: TextStyle(color: Colors.grey)),
              const Divider(),
              if ((t['HasItems'] ?? 0) > 0)
                ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.green),
                  title: const Text('Ver Cupom Fiscal (Itens da Compra)'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _showReceiptModal((t['id'] ?? t['ID']).toString(), t['Descricao'] ?? t['descricao'] ?? '');
                  },
                ),
              if (isTransfer)
                ListTile(
                  leading: Icon((t['tipo'] ?? t['Tipo']) == 'Receita' ? Icons.undo : Icons.redo, color: Colors.orange),
                  title: Text((t['tipo'] ?? t['Tipo']) == 'Receita' ? 'Devolver Valor' : 'Recuperar Valor'),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    // Mostra um loading rápido enquanto busca a outra ponta
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => const Center(child: CircularProgressIndicator()),
                    );
                    
                    try {
                      final db = await SupabaseHelper.instance.database;
                      // Buscar a transação irmã com o mesmo transferencia_id diretamente pelo Supabase Client
                      final supabase = Supabase.instance.client;
                      final response = await supabase
                          .from('transacoes')
                          .select()
                          .eq('transferencia_id', transferId)
                          .filter('deleted_at', 'is', null);
                      
                      final irmaos = List<Map<String, dynamic>>.from(response as List);
                      
                      if (!context.mounted) return;
                      Navigator.pop(context); // Remove o loading dialog
                      
                      if (irmaos.length >= 2) {
                        // Identificar quem enviou (Despesa) e quem recebeu (Receita) na transação original
                        final despesaOrig = irmaos.firstWhere((x) => (x['tipo'] ?? x['Tipo']) == 'Despesa');
                        final receitaOrig = irmaos.firstWhere((x) => (x['tipo'] ?? x['Tipo']) == 'Receita');
                        
                        final novoDestinatarioId = despesaOrig['usuario_id'] ?? despesaOrig['Usuario_ID'];
                        final novoRemetenteId = receitaOrig['usuario_id'] ?? receitaOrig['Usuario_ID'];
                        
                        final contaOrigemDevolucao = receitaOrig['conta_id'] ?? receitaOrig['Conta_ID'];
                        final contaDestinoDevolucao = despesaOrig['conta_id'] ?? despesaOrig['Conta_ID'];
                        final valorDevolucao = ((despesaOrig['valor'] ?? despesaOrig['Valor'] ?? 0) as num).toDouble();
                        
                        // Buscar o nome do novo destinatário
                        final destUserList = await db.query(SupabaseHelper.tableUsuarios, where: 'id = ?', whereArgs: [novoDestinatarioId]);
                        final destUserName = destUserList.isNotEmpty ? (destUserList.first['nome'] ?? destUserList.first['Nome'] ?? 'Usuário') : 'Usuário';

                        if (!context.mounted) return;
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FamilyTransferScreen(
                              sourceUserId: novoRemetenteId.toString(),
                              targetUserId: novoDestinatarioId.toString(),
                              targetUserName: destUserName.toString(),
                              initialValor: valorDevolucao,
                              initialContaOrigem: contaOrigemDevolucao?.toString(),
                              initialContaDestino: contaDestinoDevolucao?.toString(),
                            ),
                          ),
                        ).then((_) => _loadTransactions());
                      } else {
                        // Heurística de Fallback caso RLS bloqueie a leitura da outra ponta ou o banco não retorne
                        final singleTx = irmaos.isNotEmpty ? irmaos.first : t;
                        final tipoTx = singleTx['tipo'] ?? singleTx['Tipo'];
                        final desc = (singleTx['descricao'] ?? singleTx['Descricao'] ?? '').toString();
                        final valorDevolucao = ((singleTx['valor'] ?? singleTx['Valor'] ?? 0) as num).toDouble();
                        
                        String targetName = '';
                        if (tipoTx == 'Despesa') {
                          // Descrição: "Transferência Familiar para Maria" -> extrair "Maria"
                          if (desc.contains('para ')) {
                            targetName = desc.split('para ').last.trim();
                          }
                        } else {
                          // Descrição: "Transferência Familiar de Clovis" -> extrair "Clovis"
                          if (desc.contains('de ')) {
                            targetName = desc.split('de ').last.trim();
                          }
                        }
                        
                        // Buscar o usuário pelo nome extraído
                        final db = await SupabaseHelper.instance.database;
                        final matchUsers = await db.query(
                          SupabaseHelper.tableUsuarios,
                          where: 'nome = ?',
                          whereArgs: [targetName],
                        );
                        
                        if (matchUsers.isEmpty) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Erro: Não foi possível localizar o usuário de destino no banco.'), backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        
                        final targetUser = matchUsers.first;
                        final targetUserId = targetUser['id'] ?? targetUser['ID'];
                        final targetUserName = targetUser['nome'] ?? targetUser['Nome'];
                        
                        final String logadoId = (singleTx['usuario_id'] ?? singleTx['Usuario_ID']).toString();
                        
                        String? sourceUserId;
                        String actualTargetUserId = '';
                        String actualTargetUserName = '';
                        String? initialContaOrigem;
                        String? initialContaDestino;

                        if (tipoTx == 'Despesa') {
                          // Remetente do estorno: Maria
                          sourceUserId = targetUserId.toString();
                          // Destinatário do estorno: Clovis (logado)
                          actualTargetUserId = logadoId;
                          actualTargetUserName = 'Usuário'; // Será resolvido na inicialização da tela
                          initialContaDestino = (singleTx['conta_id'] ?? singleTx['Conta_ID'])?.toString();
                        } else {
                          // Remetente do estorno: Maria (logada)
                          sourceUserId = logadoId;
                          // Destinatário do estorno: Clovis
                          actualTargetUserId = targetUserId.toString();
                          actualTargetUserName = targetUserName.toString();
                          initialContaOrigem = (singleTx['conta_id'] ?? singleTx['Conta_ID'])?.toString();
                        }
                        
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FamilyTransferScreen(
                              sourceUserId: sourceUserId,
                              targetUserId: actualTargetUserId,
                              targetUserName: actualTargetUserName,
                              initialValor: valorDevolucao,
                              initialContaOrigem: initialContaOrigem,
                              initialContaDestino: initialContaDestino,
                            ),
                          ),
                        ).then((_) => _loadTransactions());
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // Garante fechar o loading em caso de erro
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao buscar dados: $e')),
                        );
                      }
                    }
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Editar Transação'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransactionFormScreen(transactionId: t['id'] ?? t['ID']),
                      ),
                    ).then((_) => _loadTransactions());
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Excluir Transação'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Excluir Transação?'),
                      content: const Text('Esta ação não pode ser desfeita.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deleteTransaction((t['id'] ?? t['ID']).toString());
                          },
                          child: const Text('Excluir'),
                        )
                      ],
                    )
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  void _openFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filtros e Ordenação', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  const Text('Status da Transação', style: TextStyle(fontWeight: FontWeight.w600)),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Todos', label: Text('Todos')),
                      ButtonSegment(value: 'Pagas', label: Text('Pagas')),
                      ButtonSegment(value: 'Pendentes', label: Text('Pendentes')),
                    ],
                    selected: {_filterStatus},
                    onSelectionChanged: (val) => setModalState(() => _filterStatus = val.first),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text('Mês', style: TextStyle(fontWeight: FontWeight.w600)),
                  DropdownButton<String?>(
                    isExpanded: true,
                    value: _filterMonth,
                    hint: const Text('Últimos 90 dias'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Últimos 90 dias')),
                      ...List.generate(12, (index) {
                        final now = DateTime.now();
                        final d = DateTime(now.year, now.month - index, 1);
                        final val = DateFormat('yyyy-MM').format(d);
                        final label = DateFormat('MMM/yyyy', 'pt_BR').format(d);
                        return DropdownMenuItem(value: val, child: Text(label.toUpperCase()));
                      })
                    ],
                    onChanged: (val) => setModalState(() => _filterMonth = val),
                  ),

                  const SizedBox(height: 24),
                  const Text('Ordenar por', style: TextStyle(fontWeight: FontWeight.w600)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _sortOrder,
                    items: const [
                      DropdownMenuItem(value: 't.Data DESC', child: Text('Mais recentes primeiro')),
                      DropdownMenuItem(value: 't.Data ASC', child: Text('Mais antigas primeiro')),
                      DropdownMenuItem(value: 't.Valor DESC', child: Text('Maior valor primeiro')),
                    ],
                    onChanged: (val) => setModalState(() => _sortOrder = val!),
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _loadTransactions();
                      },
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text('Aplicar Filtros'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _showReceiptModal(String transacaoId, String transacaoTitle) async {
    final db = await SupabaseHelper.instance.database;
    final items = await db.query(
      SupabaseHelper.tableListaCompras, 
      where: 'Transacao_ID = ?', 
      whereArgs: [transacaoId]
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Column(
              children: [
                const SizedBox(height: 16),
                const Icon(Icons.receipt_long, size: 48, color: Colors.green),
                const SizedBox(height: 8),
                Text('Cupom Fiscal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(transacaoTitle, style: const TextStyle(color: Colors.grey)),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final preco = (item['Preco'] ?? item['preco'] ?? 0) as num;
                      final qtde = (item['Quantidade'] ?? item['quantidade'] ?? 1) as num;
                      final total = preco * qtde;
                      return ListTile(
                        title: Text(item['Nome'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${qtde.toString().replaceAll('.0', '')}x de ${CurrencyFormatter.format(preco.toDouble())}'),
                        trailing: Text(CurrencyFormatter.format(total.toDouble()), style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'Pesquisar (Nome, Valor, Categoria)',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white60),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          onChanged: (val) {
            _searchQuery = val;
            _loadTransactions();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _openFilterDialog,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? const Center(child: Text('Nenhuma transação encontrada.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final t = _transactions[index];
                    final isReceita = t['Tipo'] == 'Receita';
                    final date = DateTime.tryParse(t['Data']?.toString() ?? '') ?? DateTime.now();
                    final isPaga = t['Paga'] == 1;
                    
                    // Bank Logo logic
                    final bancoCode = t['Codigo_Banco']?.toString() ?? '999';
                    final banco = BancosBrasil.obterBancoPorCodigo(bancoCode);
                    final bancoColor = Color(int.parse(banco.colorHex.replaceAll('#', '0xFF')));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: isPaga ? null : BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.orange.withOpacity(0.6), blurRadius: 12, spreadRadius: 1),
                        ],
                      ),
                      child: Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: isPaga ? BorderSide.none : const BorderSide(color: Colors.orange, width: 1.5),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showTransactionOptions(t),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(color: bancoColor, borderRadius: BorderRadius.circular(12)),
                                      child: Icon(banco.iconData ?? Icons.account_balance, color: Colors.white),
                                    ),
                                    if (!isPaga)
                                      Positioned(
                                        right: -2, top: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                          child: const Icon(Icons.warning, color: Colors.orange, size: 14),
                                        ),
                                      )
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t['Descricao'] ?? t['descricao'] ?? 'Sem Descrição', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, decoration: isPaga ? null : TextDecoration.lineThrough)),
                                      const SizedBox(height: 4),
                                      Text(t['CategoriaNome'].toString() + ' • ' + t['UsuarioNome'].toString(), style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                                      Text(banco.nome + ' (' + t['MetodoNome'].toString() + ')', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      (isReceita ? '+ ' : '- ') + CurrencyFormatter.format(t['Valor']),
                                      style: TextStyle(
                                        color: isReceita ? Colors.green : Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(DateFormat('dd/MM/yy').format(date), style: const TextStyle(fontSize: 11)),
                                    if (!isPaga)
                                      const Text('Pendente', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
