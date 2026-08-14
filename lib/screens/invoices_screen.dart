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
    final metodoId = widget.metodo['id'] ?? widget.metodo['ID'];
    final supabase = SupabaseHelper.instance.client;
    
    // Buscar diretamente do Supabase Client para garantir todos os campos
    final resRaw = await supabase
        .from('transacoes')
        .select('*, categorias(*)')
        .eq('metodo_id', metodoId)
        .filter('deleted_at', 'is', null)
        .order('data_fatura', ascending: false)
        .order('data', ascending: false);

    final List<Map<String, dynamic>> res = List<Map<String, dynamic>>.from(resRaw as List);

    final dfRaw = widget.metodo['dia_fechamento'] ?? widget.metodo['Dia_Fechamento'];
    final dvRaw = widget.metodo['dia_vencimento'] ?? widget.metodo['Dia_Vencimento'];
    int diaFechamento = int.tryParse(dfRaw?.toString() ?? '15') ?? 15;
    int diaVencimento = int.tryParse(dvRaw?.toString() ?? '25') ?? 25;

    Map<String, List<Map<String, dynamic>>> faturasTemp = {};

    for (var t in res) {
      String? dataFaturaStr = (t['data_fatura'] ?? t['Data_Fatura'])?.toString();
      String? dataStr = (t['data'] ?? t['Data'])?.toString();
      DateTime dtCompra = DateTime.tryParse(dataStr ?? '') ?? DateTime.now();

      DateTime faturaRef;
      if (dataFaturaStr != null && dataFaturaStr.isNotEmpty) {
        faturaRef = DateTime.tryParse(dataFaturaStr) ?? dtCompra;
      } else {
        // Lógica de fechamento clássica se não houver data_fatura explícita
        faturaRef = dtCompra;
        if (dtCompra.day > diaFechamento) {
          faturaRef = DateTime(dtCompra.year, dtCompra.month + 1, diaVencimento);
        } else {
          faturaRef = DateTime(dtCompra.year, dtCompra.month, diaVencimento);
        }
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
      final id = t['id'] ?? t['ID'];
      final paga = t['paga'] ?? t['Paga'];
      if (paga == 0 || paga == false) {
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
          final preco = ((i['preco'] ?? i['Preco'] ?? 0) as num).toDouble();
          final qtd = ((i['quantidade'] ?? i['Quantidade'] ?? 1) as num).toDouble();
          cupomTotal += preco * qtd;
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
                    final nome = (item['nome'] ?? item['Nome'] ?? '').toString();
                    final preco = ((item['preco'] ?? item['Preco'] ?? 0) as num).toDouble();
                    final qtd = ((item['quantidade'] ?? item['Quantidade'] ?? 1) as num).toDouble();
                    final totalItem = preco * qtd;
                    return ListTile(
                      title: Text(nome),
                      subtitle: Text('${qtd}x ${CurrencyFormatter.format(preco)}'),
                      trailing: Text(CurrencyFormatter.format(totalItem), style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final nomeMetodo = widget.metodo['nome'] ?? widget.metodo['Nome'] ?? 'Cartão';
    return Scaffold(
      appBar: AppBar(
        title: Text('Faturas: $nomeMetodo'),
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
                      final valor = ((t['valor'] ?? t['Valor'] ?? 0) as num).toDouble();
                      final paga = t['paga'] ?? t['Paga'];
                      totalFatura += valor;
                      if (paga == 0 || paga == false) isTotalmentePaga = false;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        initiallyExpanded: index == 0,
                        title: Text('Vencimento: $vencimento', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(
                          'Total: ${CurrencyFormatter.format(totalFatura)} • ${isTotalmentePaga ? "Fatura Paga" : "Aberta"}', 
                          style: TextStyle(color: isTotalmentePaga ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.w600)
                        ),
                        children: [
                          if (!isTotalmentePaga)
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _pagarFatura(vencimento, txs),
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('Pagar Fatura Completa'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green, 
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ),
                          ...txs.map((t) {
                            final paga = t['paga'] ?? t['Paga'];
                            final isPaga = (paga == 1 || paga == true);
                            final valor = ((t['valor'] ?? t['Valor'] ?? 0) as num).toDouble();
                            final desc = (t['descricao'] ?? t['Descricao'] ?? '').toString();
                            final dataStr = (t['data'] ?? t['Data'] ?? '').toString();
                            final dt = DateTime.tryParse(dataStr);
                            final dataFormatada = dt != null ? DateFormat('dd/MM/yyyy').format(dt) : dataStr;
                            final id = (t['id'] ?? t['ID'])?.toString() ?? '';

                            return ListTile(
                              leading: Icon(isPaga ? Icons.check_circle : Icons.pending, color: isPaga ? Colors.greenAccent : Colors.orangeAccent),
                              title: Text(desc, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(dataFormatada),
                              trailing: Text(CurrencyFormatter.format(valor), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              onTap: () => _verCupomFiscal(id),
                            );
                          }).toList(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
