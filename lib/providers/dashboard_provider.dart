import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/supabase_helper.dart';
import 'settings_provider.dart';

final dashboardDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = SupabaseHelper.instance.client;
  
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
  final startOfNextMonth = DateTime(now.year, now.month + 1, 1).toIso8601String();

  // 1. Fetch total balance (Receitas - Despesas)
  final List<dynamic> transacoesRaw = await supabase
      .from('transacoes')
      .select('*, categorias(*), contas_bancarias(*), metodos_pagamento(*)')
      .filter('deleted_at', 'is', null);

  final List<Map<String, dynamic>> transacoes = transacoesRaw.map((e) => CaseInsensitiveMap(e as Map<String, dynamic>)).toList();

  double totalBalance = 0.0;
  for (var t in transacoes) {
    final paga = (t['paga'] ?? t['Paga']);
    if (paga == 1 || paga == true) {
      double valor = ((t['valor'] ?? t['Valor']) as num).toDouble();
      final tipo = t['tipo'] ?? t['Tipo'];
      totalBalance += (tipo == 'Receita') ? valor : -valor;
    }
  }

  // 2. Fetch individual balances
  final userLimitSetting = await ref.watch(settingsProvider.future);
  int? limit;
  if (userLimitSetting != 'Ilimitado') {
     limit = int.tryParse(userLimitSetting);
  }
  
  var usersQuery = supabase.from('usuarios').select('id, nome, ordem').filter('deleted_at', 'is', null).order('ordem', ascending: true);
  if (limit != null) usersQuery = usersQuery.limit(limit);
  final List<dynamic> usersRaw = await usersQuery;
  final List<Map<String, dynamic>> users = usersRaw.map((e) => CaseInsensitiveMap(e as Map<String, dynamic>)).toList();
  
  List<Map<String, dynamic>> userBalances = [];
  for (var u in users) {
    String uId = (u['id'] ?? u['ID']).toString();
    String uName = u['nome'] ?? u['Nome'] ?? '';
    
    double uBalance = 0.0;
    for (var t in transacoes) {
      final paga = (t['paga'] ?? t['Paga']);
      final uIdTrans = (t['usuario_id'] ?? t['Usuario_ID'])?.toString();
      if ((paga == 1 || paga == true) && uIdTrans == uId) {
        double valor = ((t['valor'] ?? t['Valor']) as num).toDouble();
        final tipo = t['tipo'] ?? t['Tipo'];
        uBalance += (tipo == 'Receita') ? valor : -valor;
      }
    }
    userBalances.add({'id': uId, 'nome': uName, 'saldo': uBalance});
  }

  // 3. Fetch expenses by category for current month
  Map<String, Map<String, dynamic>> catSums = {};
  for (var t in transacoes) {
    final paga = (t['paga'] ?? t['Paga']);
    final tipo = t['tipo'] ?? t['Tipo'];
    if (tipo == 'Despesa' && (paga == 1 || paga == true)) {
      String dataRef = (t['data_fatura'] ?? t['Data_Fatura'] ?? t['data'] ?? t['Data'] ?? '').toString();
      if (dataRef.compareTo(startOfMonth) >= 0 && dataRef.compareTo(startOfNextMonth) < 0) {
        final catMap = t['categorias'] != null ? CaseInsensitiveMap(t['categorias']) : null;
        if (catMap != null) {
          String cId = (t['categoria_id'] ?? t['Categoria_ID'] ?? '').toString();
          String cNome = catMap['nome'] ?? catMap['Nome'] ?? '';
          String cCor = catMap['cor_hexadecimal'] ?? catMap['Cor_Hexadecimal'] ?? '#9E9E9E';
          double valor = ((t['valor'] ?? t['Valor']) as num).toDouble();
          
          if (!catSums.containsKey(cId)) {
            catSums[cId] = {'Nome': cNome, 'Cor_Hexadecimal': cCor, 'total': 0.0};
          }
          catSums[cId]!['total'] += valor;
        }
      }
    }
  }
  
  final List<Map<String, dynamic>> categoryExpenses = catSums.values.toList();
  categoryExpenses.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

  // 4. Recent transactions
  final List<Map<String, dynamic>> recentTransactions = [];
  for (var t in transacoes) {
    String tData = (t['data'] ?? t['Data'] ?? '').toString();
    if (tData.compareTo(now.toIso8601String()) <= 0) {
      final catMap = t['categorias'] != null ? CaseInsensitiveMap(t['categorias']) : null;
      final contaMap = t['contas_bancarias'] != null ? CaseInsensitiveMap(t['contas_bancarias']) : null;
      final metMap = t['metodos_pagamento'] != null ? CaseInsensitiveMap(t['metodos_pagamento']) : null;

      recentTransactions.add({
        ...t,
        'Valor': ((t['valor'] ?? t['Valor']) as num).toDouble(),
        'Tipo': t['tipo'] ?? t['Tipo'],
        'Data': tData,
        'Paga': (t['paga'] ?? t['Paga']) == true ? 1 : (t['paga'] ?? t['Paga'] ?? 0),
        'CategoriaNome': catMap?['nome'] ?? catMap?['Nome'] ?? 'Sem Categoria',
        'Cor_Hexadecimal': catMap?['cor_hexadecimal'] ?? catMap?['Cor_Hexadecimal'] ?? '#9E9E9E',
        'Codigo_Banco': contaMap?['codigo_banco'] ?? contaMap?['Codigo_Banco'] ?? '',
        'ContaNome': contaMap?['nome'] ?? contaMap?['Nome'] ?? 'Sem Conta',
        'MetodoNome': metMap?['nome'] ?? metMap?['Nome'] ?? 'N/A',
        'HasItems': 0,
      });
    }
  }
  recentTransactions.sort((a, b) => (b['Data']?.toString() ?? '').compareTo(a['Data']?.toString() ?? ''));
  final recent5 = recentTransactions.take(5).toList();

  // 5. Fetch Credit Cards with Bank and User Name
  final List<dynamic> creditCardsRaw = await supabase.from('metodos_pagamento')
    .select('*, contas_bancarias(*, usuarios(*))')
    .eq('tipo', 'Crédito')
    .filter('deleted_at', 'is', null);
    
  final List<Map<String, dynamic>> creditCards = creditCardsRaw.map((mpRaw) {
    final mp = CaseInsensitiveMap(mpRaw as Map<String, dynamic>);
    final conta = mp['contas_bancarias'] != null ? CaseInsensitiveMap(mp['contas_bancarias']) : null;
    final user = conta != null && conta['usuarios'] != null ? CaseInsensitiveMap(conta['usuarios']) : null;

    return <String, dynamic>{
      ...mp,
      'Nome': (mp['nome'] ?? mp['Nome'] ?? 'Cartão').toString(),
      'BancoNome': (conta?['nome'] ?? conta?['Nome'] ?? 'Banco').toString(),
      'Codigo_Banco': (conta?['codigo_banco'] ?? conta?['Codigo_Banco'] ?? '999').toString(),
      'UsuarioNome': (user?['nome'] ?? user?['Nome'] ?? '').toString(),
      'Dia_Fechamento': mp['dia_fechamento'] ?? mp['Dia_Fechamento'] ?? 'N/A',
      'Dia_Vencimento': mp['dia_vencimento'] ?? mp['Dia_Vencimento'] ?? 'N/A',
    };
  }).toList();

  return {
    'totalBalance': totalBalance,
    'userBalances': userBalances,
    'categoryExpenses': categoryExpenses,
    'recentTransactions': recent5,
    'creditCards': creditCards,
  };
});

class HideBalanceNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false; // initial temporary state
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('hideBalance') ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideBalance', state);
  }
}

final hideBalanceProvider = NotifierProvider<HideBalanceNotifier, bool>(() {
  return HideBalanceNotifier();
});
