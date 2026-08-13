import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';
import '../utils/currency_formatter.dart';
import 'package:intl/intl.dart';

import '../providers/dashboard_provider.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> metodo;

  const InvoicesScreen({super.key, required this.metodo});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transacoes = [];
  Map<String, List<Map<String, dynamic>>> _faturas = {};

  @override
  void initState() {
    super.initState();
    _loadFaturas();
  }

  Future<void> _loadFaturas() async {
    final db = await SupabaseHelper.instance.database;
    final res = await db.query(
      SupabaseHelper.tableTransacoes,
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
    final supabase = SupabaseHelper.instance.client;

    for (var t in transacoes) {
      final id = t['ID'] ?? t['id'];
      if (t['Paga'] == 0 || t['paga'] == 0) {
        await supabase.from('transacoes').update({'paga': 1}).eq('id', id);
      }
    }
    
    ref.refresh(dashboardDataProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fatura Paga com Sucesso!')));
    }
    
    _loadFaturas();
  }

  Future<void> _verCupomFiscal(String transacaoId) async {
    final db = await SupabaseHelper.instance.database;
    final itens = await db.query(SupabaseHelper.tableListaCompras, where: 'Transacao_ID = ?', whereArgs: [transacaoId]);

    if (itens.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum item associado a esta compra.')));
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double cupomTotal = 0;
        for (var i in itens) {
          cupomTotal += (i['Preco'] as num) * (i['Quantidade'] as num);
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const Text('Cupom Fiscal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    final totalItem = (item['Preco'] as num) * (item['Quantidade'] as num);
                    return ListTile(
                      title: Text(item['Nome'].toString()),
                      subtitle: Text('${item['Quantidade']}x ${CurrencyFormatter.format((item['Preco'] as num).toDouble())}'),
                      trailing: Text(CurrencyFormatter.format(totalItem.toDouble()), style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total da Compra:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(CurrencyFormatter.format(cupomTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ],
          ),
        );
      }
    );
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
                            subtitle: Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(t['Data'].toString()))),
                            trailing: Text(CurrencyFormatter.format((t['Valor'] as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () => _verCupomFiscal(t['ID'].toString()),
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
    );
  }
}
