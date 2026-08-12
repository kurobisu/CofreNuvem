import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';

final investmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await SupabaseHelper.instance.database;
  final result = await db.rawQuery('''
    SELECT i.*, u.Nome as UsuarioNome 
    FROM ${SupabaseHelper.tableInvestimentos} i
    JOIN ${SupabaseHelper.tableUsuarios} u ON i.Usuario_ID = u.ID
    WHERE i.Status = 'Ativo' OR i.Status IS NULL
    ORDER BY i.Data_Aporte DESC
  ''');
  return result;
});

final investmentHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await SupabaseHelper.instance.database;
  final result = await db.rawQuery('''
    SELECT h.Data, h.Valor, h.Investimento_ID, i.Ativo
    FROM ${SupabaseHelper.tableHistoricoRendimentos} h
    JOIN ${SupabaseHelper.tableInvestimentos} i ON h.Investimento_ID = i.ID
    WHERE i.Status = 'Ativo' OR i.Status IS NULL
    ORDER BY h.Data ASC
  ''');
  return result;
});
