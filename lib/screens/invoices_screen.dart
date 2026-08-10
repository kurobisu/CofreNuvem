import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/currency_formatter.dart';
import 'package:intl/intl.dart';

class InvoicesScreen extends StatefulWidget {
  final Map<String, dynamic> metodo;

  const InvoicesScreen({super.key, required this.metodo});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transacoes = [];
  Map<String, List<Map<String, dynamic>>> _faturas = {};

  @override
  void initState() {
    super.initState();
    _loadFaturas();
  }

  Future<void> _loadFaturas() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      DatabaseHelper.tableTransacoes,
      where: 'Metodo_ID = ?',
      whereArgs: [widget.metodo['ID']],
      orderBy: 'Data DESC',
    );

    int diaFechamento = widget.metodo['Dia_Fechamento'] ?? 15;
    int diaVencimento = widget.metodo['Dia_Vencimento'] ?? 25;

    Map<String, List<Map<String, dynamic>>> faturasTemp = {};

    for (var t in res) {
      DateTime dtCompra = DateTime.parse(t['Data'] as String);
      
      // Lógica de fechamento: se comprou DEPOIS do fechamento, cai no próximo mês
      DateTime faturaRef = dtCompra;
      if (dtCompra.day > diaFechamento) {
        faturaRef = DateTime(dtCompra.year, dtCompra.month + 1, 1);
      }
      
      String faturaKey = DateFormat('MM/yyyy').format(faturaRef);
      String vencimentoStr = '${diaVencimento.toString().padLeft(2, '0')}/$faturaKey';

      if (!faturasTemp.containsKey(vencimentoStr)) {
        faturasTemp[vencimentoStr] = [];
      }
      faturasTemp[vencimentoStr]!.add(t);
    }

    setState(() {
      _transacoes = res;
      _faturas = faturasTemp;
      _isLoading = false;
    });
  }

  Future<void> _pagarFatura(String vencimento, List<Map<String, dynamic>> transacoes) async {
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();

    for (var t in transacoes) {
      if (t['Paga'] == 0) {
        batch.update(DatabaseHelper.tableTransacoes, {'Paga': 1}, where: 'ID = ?', whereArgs: [t['ID']]);
      }
    }

    await batch.commit(noResult: true);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fatura Paga com Sucesso!')));
    }
    
    _loadFaturas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Faturas: ${widget.metodo['Nome']}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _faturas.isEmpty
              ? const Center(child: Text('Nenhuma transação neste cartão.'))
              : ListView.builder(
                  itemCount: _faturas.keys.length,
                  itemBuilder: (context, index) {
                    String vencimento = _faturas.keys.elementAt(index);
                    List<Map<String, dynamic>> txs = _faturas[vencimento]!;
                    
                    double totalFatura = 0;
                    bool isTotalmentePaga = true;
                    
                    for (var t in txs) {
                      totalFatura += (t['Valor'] as num).toDouble();
                      if (t['Paga'] == 0) isTotalmentePaga = false;
                    }

                    return ExpansionTile(
                      title: Text('Vencimento: $vencimento', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Total: ${CurrencyFormatter.format(totalFatura)}', style: TextStyle(color: isTotalmentePaga ? Colors.green : Colors.red)),
                      children: [
                        if (!isTotalmentePaga)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton.icon(
                              onPressed: () => _pagarFatura(vencimento, txs),
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Pagar Fatura Completa'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            ),
                          ),
                        ...txs.map((t) {
                          bool paga = t['Paga'] == 1;
                          return ListTile(
                            leading: Icon(paga ? Icons.check_circle : Icons.pending, color: paga ? Colors.green : Colors.orange),
                            title: Text(t['Descricao']),
                            subtitle: Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(t['Data'] as String))),
                            trailing: Text(CurrencyFormatter.format((t['Valor'] as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
    );
  }
}
