import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';

final investmentDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final db = await SupabaseHelper.instance.database;
  
  final invRes = await db.query(SupabaseHelper.tableInvestimentos, where: 'ID = ?', whereArgs: [id]);
  if (invRes.isEmpty) throw Exception('Investimento não encontrado');
  
  final historyRes = await db.query(SupabaseHelper.tableHistoricoRendimentos, where: 'Investimento_ID = ?', whereArgs: [id], orderBy: 'Data ASC');
  
  final supabase = SupabaseHelper.instance.client;
  final transRaw = await supabase
      .from('transacoes')
      .select('*, contas_bancarias(nome)')
      .eq('investimento_id', id)
      .filter('deleted_at', 'is', null)
      .order('data', ascending: false);

  final transRes = transRaw.map((r) => {
    ...r,
    'ContaNome': r['contas_bancarias']?['nome'] ?? 'Sem Conta',
  }).toList();
  
  return {
    'investment': invRes.first,
    'history': historyRes,
    'transactions': transRes,
  };
});
