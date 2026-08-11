import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';

final investmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final result = await db.rawQuery('''
    SELECT i.*, u.Nome as UsuarioNome 
    FROM ${DatabaseHelper.tableInvestimentos} i
    JOIN ${DatabaseHelper.tableUsuarios} u ON i.Usuario_ID = u.ID
    WHERE i.Status = 'Ativo' OR i.Status IS NULL
    ORDER BY i.Data_Aporte DESC
  ''');
  return result;
});

final investmentHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final result = await db.rawQuery('''
    SELECT h.Data, h.Valor, h.Investimento_ID, i.Ativo
    FROM ${DatabaseHelper.tableHistoricoRendimentos} h
    JOIN ${DatabaseHelper.tableInvestimentos} i ON h.Investimento_ID = i.ID
    WHERE i.Status = 'Ativo' OR i.Status IS NULL
    ORDER BY h.Data ASC
  ''');
  return result;
});
