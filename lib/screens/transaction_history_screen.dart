import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../utils/currency_formatter.dart';
import '../utils/transaction_helper.dart';
import '../utils/bancos_brasil.dart';
import 'transaction_form_screen.dart';
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
    final db = await DatabaseHelper.instance.database;
    
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (_filterStatus == 'Pagas') {
      whereClause += ' AND t.Paga = 1';
    } else if (_filterStatus == 'Pendentes') {
      whereClause += ' AND t.Paga = 0';
    }

    if (_filterMonth != null) {
      // _filterMonth is like '2026-08'
      whereClause += ' AND t.Data LIKE ?';
      whereArgs.add('$_filterMonth%');
    }

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT t.*, 
             c.Nome as CategoriaNome, c.Cor_Hexadecimal, 
             cb.Codigo_Banco, cb.Nome as ContaNome,
             u.Nome as UsuarioNome,
             mp.Nome as MetodoNome,
             (SELECT COUNT(ID) FROM ${DatabaseHelper.tableListaCompras} WHERE Transacao_ID = t.ID) as HasItems
      FROM ${DatabaseHelper.tableTransacoes} t
      JOIN ${DatabaseHelper.tableCategorias} c ON t.Categoria_ID = c.ID
      JOIN ${DatabaseHelper.tableContasBancarias} cb ON t.Conta_ID = cb.ID
      JOIN ${DatabaseHelper.tableUsuarios} u ON t.Usuario_ID = u.ID
      JOIN ${DatabaseHelper.tableMetodosPagamento} mp ON t.Metodo_ID = mp.ID
      WHERE $whereClause
      ORDER BY $_sortOrder
    ''', whereArgs);

    setState(() {
      _transactions = result;
      _isLoading = false;
    });
  }

  Future<void> _togglePagaStatus(int id, int currentStatus) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(DatabaseHelper.tableTransacoes, {'Paga': currentStatus == 1 ? 0 : 1}, where: 'ID = ?', whereArgs: [id]);
    _loadTransactions();
    ref.refresh(dashboardDataProvider);
  }

  Future<void> _deleteTransaction(int id) async {
    await TransactionHelper.deleteTransactionWithConfirmation(context, id, ref, () {
      _loadTransactions();
      ref.refresh(dashboardDataProvider);
    });
  }

  void _showTransactionOptions(Map<String, dynamic> t) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(t['Descricao'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Text('Opções da Transação', style: TextStyle(color: Colors.grey)),
              const Divider(),
              if ((t['HasItems'] ?? 0) > 0)
                ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.green),
                  title: const Text('Ver Cupom Fiscal (Itens da Compra)'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReceiptModal(t['ID'], t['Descricao']);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Editar Transação'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransactionFormScreen(transactionId: t['ID']),
                    ),
                  ).then((_) => _loadTransactions());
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Excluir Transação'),
                onTap: () {
                  Navigator.pop(context);
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
                            _deleteTransaction(t['ID']);
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
                    hint: const Text('Todos os meses'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
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

  Future<void> _showReceiptModal(int transacaoId, String transacaoTitle) async {
    final db = await DatabaseHelper.instance.database;
    final items = await db.query(
      DatabaseHelper.tableListaCompras, 
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
                      final preco = item['Preco'] as num;
                      final qtde = item['Quantidade'] as num;
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
        title: const Text('Histórico Completo'),
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
                    final date = DateTime.parse(t['Data']);
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
                                      Text(t['Descricao'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, decoration: isPaga ? null : TextDecoration.lineThrough)),
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
