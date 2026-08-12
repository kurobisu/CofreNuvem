import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';

final investmentDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final db = await SupabaseHelper.instance.database;
  
  final invRes = await db.query(SupabaseHelper.tableInvestimentos, where: 'ID = ?', whereArgs: [id]);
  if (invRes.isEmpty) throw Exception('Investimento não encontrado');
  
  final historyRes = await db.query(SupabaseHelper.tableHistoricoRendimentos, where: 'Investimento_ID = ?', whereArgs: [id], orderBy: 'Data ASC');
  
  final transRes = await db.rawQuery('''
    SELECT t.*, c.Nome as ContaNome 
    FROM ${SupabaseHelper.tableTransacoes} t
    LEFT JOIN ${SupabaseHelper.tableContasBancarias} c ON t.Conta_ID = c.ID
    WHERE t.Investimento_ID = ?
    ORDER BY t.Data DESC
  ''', [id]);
  
  return {
    'investment': invRes.first,
    'history': historyRes,
    'transactions': transRes,
  };
});
