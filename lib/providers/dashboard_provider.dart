import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';
import 'settings_provider.dart';

final dashboardDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = await SupabaseHelper.instance.database;
  
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
  final startOfNextMonth = DateTime(now.year, now.month + 1, 1).toIso8601String();

  // 1. Fetch total balance (Receitas - Despesas)
  final List<Map<String, dynamic>> resTotal = await db.rawQuery(
    "SELECT SUM(CASE WHEN Tipo = 'Receita' THEN Valor ELSE -Valor END) as saldo FROM transacoes WHERE Paga = 1 AND deleted_at IS NULL"
  );
  double totalBalance = (resTotal.first['saldo'] as num?)?.toDouble() ?? 0.0;

  // 2. Fetch individual balances
  final userLimitSetting = await ref.watch(settingsProvider.future);
  int? limit;
  if (userLimitSetting != 'Ilimitado') {
     limit = int.tryParse(userLimitSetting);
  }
  final List<Map<String, dynamic>> users = await db.query(SupabaseHelper.tableUsuarios, orderBy: 'Ordem ASC', limit: limit);
  List<Map<String, dynamic>> userBalances = [];
  
  for (var u in users) {
    String uId = u['id'].toString();
    String uName = u['nome'];
    final List<Map<String, dynamic>> resUser = await db.rawQuery(
      "SELECT SUM(CASE WHEN Tipo = 'Receita' THEN Valor ELSE -Valor END) as saldo FROM transacoes WHERE Usuario_ID = ? AND Paga = 1 AND deleted_at IS NULL", 
      [uId]
    );
    double uBalance = (resUser.first['saldo'] as num?)?.toDouble() ?? 0.0;
    userBalances.add({'id': uId, 'nome': uName, 'saldo': uBalance});
  }

  // 3. Fetch expenses by category for current month
  final List<Map<String, dynamic>> categoryExpenses = await db.rawQuery('''
    SELECT c.Nome, c.Cor_Hexadecimal, SUM(t.Valor) as total 
    FROM transacoes t
    JOIN categorias c ON t.Categoria_ID = c.ID
    WHERE t.Tipo = 'Despesa' AND COALESCE(t.Data_Fatura, t.Data) >= ? AND COALESCE(t.Data_Fatura, t.Data) < ? AND t.Paga = 1 AND t.deleted_at IS NULL
    GROUP BY c.ID
    ORDER BY total DESC
  ''', [startOfMonth, startOfNextMonth]);

  // 4. Recent transactions
  final List<Map<String, dynamic>> recentTransactions = await db.rawQuery('''
    SELECT t.*, c.Nome as CategoriaNome, c.Cor_Hexadecimal, cb.Codigo_Banco, cb.Nome as ContaNome, mp.Nome as MetodoNome,
    (SELECT COUNT(ID) FROM lista_compras WHERE Transacao_ID = t.ID AND deleted_at IS NULL) as HasItems
    FROM transacoes t
    JOIN categorias c ON t.Categoria_ID = c.ID
    JOIN contas_bancarias cb ON t.Conta_ID = cb.ID
    JOIN metodos_pagamento mp ON t.Metodo_ID = mp.ID
    WHERE t.Data <= ? AND t.deleted_at IS NULL
    ORDER BY t.Data DESC
    LIMIT 5
  ''', [now.toIso8601String()]);

  // 5. Fetch Credit Cards with Bank and User Name
  final List<Map<String, dynamic>> creditCards = await db.rawQuery('''
    SELECT mp.*, cb.Nome as BancoNome, cb.Codigo_Banco, u.Nome as UsuarioNome
    FROM metodos_pagamento mp
    JOIN contas_bancarias cb ON mp.Conta_ID = cb.ID
    JOIN usuarios u ON cb.Usuario_ID = u.ID
    WHERE mp.Tipo = 'Crédito' AND mp.deleted_at IS NULL
  ''');

  return {
    'totalBalance': totalBalance,
    'userBalances': userBalances,
    'categoryExpenses': categoryExpenses,
    'recentTransactions': recentTransactions,
    'creditCards': creditCards,
  };
});

class HideBalanceNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final hideBalanceProvider = NotifierProvider<HideBalanceNotifier, bool>(() {
  return HideBalanceNotifier();
});
