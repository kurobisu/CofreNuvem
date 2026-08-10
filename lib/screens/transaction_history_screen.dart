import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../utils/currency_formatter.dart';
import '../utils/bancos_brasil.dart';
import '../theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT t.*, 
             c.Nome as CategoriaNome, c.Cor_Hexadecimal, 
             cb.Codigo_Banco, cb.Nome as ContaNome,
             u.Nome as UsuarioNome
      FROM ${DatabaseHelper.tableTransacoes} t
      JOIN ${DatabaseHelper.tableCategorias} c ON t.Categoria_ID = c.ID
      JOIN ${DatabaseHelper.tableContasBancarias} cb ON t.Conta_ID = cb.ID
      JOIN ${DatabaseHelper.tableUsuarios} u ON t.Usuario_ID = u.ID
      ORDER BY t.Data DESC
    ''');

    setState(() {
      _transactions = result;
      _isLoading = false;
    });
  }

  Future<void> _deleteTransaction(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableTransacoes, where: 'ID = ?', whereArgs: [id]);
    _loadTransactions();
    ref.refresh(dashboardDataProvider); // Update dashboard
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico Completo')),
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
                    
                    // Bank Logo logic
                    final bancoCode = t['Codigo_Banco']?.toString() ?? '999';
                    final banco = BancosBrasil.obterBancoPorCodigo(bancoCode);
                    final bancoColor = Color(int.parse(banco.colorHex.replaceAll('#', '0xFF')));

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showTransactionOptions(t),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(color: bancoColor, borderRadius: BorderRadius.circular(12)),
                                child: Icon(banco.iconData ?? Icons.account_balance, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t['Descricao'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(t['CategoriaNome'].toString() + ' • ' + t['UsuarioNome'].toString(), style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                                    Text(banco.nome + ' (' + t['ContaNome'].toString() + ')', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
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
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(DateFormat('dd/MM/yy').format(date), style: const TextStyle(fontSize: 12)),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
