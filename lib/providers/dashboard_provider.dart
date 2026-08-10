import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';

final dashboardDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
  final startOfNextMonth = DateTime(now.year, now.month + 1, 1).toIso8601String();

  // 1. Fetch total balance (Receitas - Despesas) APENAS DO MÊS ATUAL
  final List<Map<String, dynamic>> resTotal = await db.rawQuery(
    "SELECT SUM(CASE WHEN Tipo = 'Receita' THEN Valor ELSE -Valor END) as saldo FROM ${DatabaseHelper.tableTransacoes} WHERE Data >= ? AND Data < ? AND Paga = 1",
    [startOfMonth, startOfNextMonth]
  );
  double totalBalance = (resTotal.first['saldo'] as num?)?.toDouble() ?? 0.0;

  // 2. Fetch individual balances APENAS DO MÊS ATUAL
  final List<Map<String, dynamic>> users = await db.query(DatabaseHelper.tableUsuarios, orderBy: 'Ordem ASC');
  List<Map<String, dynamic>> userBalances = [];
  
  for (var u in users) {
    int uId = u['ID'];
    String uName = u['Nome'];
    final List<Map<String, dynamic>> resUser = await db.rawQuery(
      "SELECT SUM(CASE WHEN Tipo = 'Receita' THEN Valor ELSE -Valor END) as saldo FROM ${DatabaseHelper.tableTransacoes} WHERE Usuario_ID = ? AND Data >= ? AND Data < ? AND Paga = 1", 
      [uId, startOfMonth, startOfNextMonth]
    );
    double uBalance = (resUser.first['saldo'] as num?)?.toDouble() ?? 0.0;
    userBalances.add({'nome': uName, 'saldo': uBalance});
  }

  // 3. Fetch expenses by category for current month
  final List<Map<String, dynamic>> categoryExpenses = await db.rawQuery('''
    SELECT c.Nome, c.Cor_Hexadecimal, SUM(t.Valor) as total 
    FROM ${DatabaseHelper.tableTransacoes} t
    JOIN ${DatabaseHelper.tableCategorias} c ON t.Categoria_ID = c.ID
    WHERE t.Tipo = 'Despesa' AND t.Data >= ? AND t.Data < ? AND t.Paga = 1
    GROUP BY c.ID
    ORDER BY total DESC
  ''', [startOfMonth, startOfNextMonth]);

  // 4. Recent transactions
  final List<Map<String, dynamic>> recentTransactions = await db.rawQuery('''
    SELECT t.*, c.Nome as CategoriaNome, c.Cor_Hexadecimal, cb.Codigo_Banco, cb.Nome as ContaNome, mp.Nome as MetodoNome
    FROM ${DatabaseHelper.tableTransacoes} t
    JOIN ${DatabaseHelper.tableCategorias} c ON t.Categoria_ID = c.ID
    JOIN ${DatabaseHelper.tableContasBancarias} cb ON t.Conta_ID = cb.ID
    JOIN ${DatabaseHelper.tableMetodosPagamento} mp ON t.Metodo_ID = mp.ID
    WHERE t.Data <= ? AND t.Paga = 1
    ORDER BY t.Data DESC
    LIMIT 5
  ''', [now.toIso8601String()]);

  return {
    'totalBalance': totalBalance,
    'userBalances': userBalances,
    'categoryExpenses': categoryExpenses,
    'recentTransactions': recentTransactions,
  };
});
