import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';

final investmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final result = await db.rawQuery('''
    SELECT i.*, u.Nome as UsuarioNome 
    FROM ${DatabaseHelper.tableInvestimentos} i
    JOIN ${DatabaseHelper.tableUsuarios} u ON i.Usuario_ID = u.ID
    ORDER BY i.Data_Aporte DESC
  ''');
  return result;
});
