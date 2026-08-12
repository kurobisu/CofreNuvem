import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseHelper {
  static final SupabaseHelper instance = SupabaseHelper._privateConstructor();
  SupabaseHelper._privateConstructor();

  final _client = Supabase.instance.client;

  // Tables
  static const tableUsuarios = 'usuarios';
  static const tableContasBancarias = 'contas_bancarias';
  static const tableContasCompartilhadas = 'contas_compartilhadas';
  static const tableMetodosPagamento = 'metodos_pagamento';
  static const tableCategorias = 'categorias';
  static const tableTransacoes = 'transacoes';
  static const tableInvestimentos = 'investimentos';
  static const tableHistoricoRendimentos = 'historico_rendimentos';
  static const tableListaCompras = 'lista_compras';
  static const tableProdutos = 'produtos';

  // Getter mockado para não quebrar a sintaxe final db = await SupabaseHelper.instance.database;
  Future<SupabaseProxy> get database async => SupabaseProxy(_client);

}

class SupabaseProxy {
  final SupabaseClient _client;
  SupabaseProxy(this._client);

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    dynamic req = _client.from(table).select(columns?.join(',') ?? '*');
    
    // Filtros básicos
    if (where != null && whereArgs != null) {
      final conditions = where.split(' AND ');
      for (int i = 0; i < conditions.length; i++) {
        final cond = conditions[i].trim();
        if (cond.contains('=')) {
          final column = cond.split('=')[0].trim().toLowerCase();
          final val = whereArgs[i];
          if (val != null) req = req.eq(column, val as Object);
        } else if (cond.contains('IN')) {
          // Complex parsing not fully supported in this mock, use raw queries when needed
        }
      }
    }
    
    if (orderBy != null) {
      final parts = orderBy.split(' ');
      final col = parts[0].toLowerCase();
      final asc = parts.length > 1 ? parts[1].toUpperCase() != 'DESC' : true;
      req = req.order(col, ascending: asc);
    }
    
    if (limit != null) {
      req = req.limit(limit);
    }
    
    return await req;
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    // rawQuery is not fully supported in this proxy without RPC.
    // Returning empty list temporarily to satisfy compiler.
    return [];
  }

  Future<String> insert(String table, Map<String, Object?> values, {dynamic conflictAlgorithm}) async {
    // lowercase all keys
    final lowerValues = values.map((k, v) => MapEntry(k.toLowerCase(), v));
    final res = await _client.from(table).insert(lowerValues).select();
    return res.first['id'].toString();
  }

  Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs}) async {
    final lowerValues = values.map((k, v) => MapEntry(k.toLowerCase(), v));
    dynamic req = _client.from(table).update(lowerValues);
    
    if (where != null && whereArgs != null) {
      final conditions = where.split(' AND ');
      for (int i = 0; i < conditions.length; i++) {
        final cond = conditions[i].trim();
        if (cond.contains('=')) {
          final column = cond.split('=')[0].trim().toLowerCase();
          final val = whereArgs[i];
          if (val != null) req = req.eq(column, val as Object);
        }
      }
    }
    await req;
    return 1; // mock affected rows
  }

  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    dynamic req = _client.from(table).delete();
    
    if (where != null && whereArgs != null) {
      final conditions = where.split(' AND ');
      for (int i = 0; i < conditions.length; i++) {
        final cond = conditions[i].trim();
        if (cond.contains('=')) {
          final column = cond.split('=')[0].trim().toLowerCase();
          final val = whereArgs[i];
          if (val != null) req = req.eq(column, val as Object);
        }
      }
    }
    await req;
    return 1; // mock affected rows
  }
  
  SupabaseBatch batch() {
    return SupabaseBatch(this);
  }
}

class SupabaseBatch {
  final SupabaseProxy _proxy;
  final List<Function> _operations = [];
  
  SupabaseBatch(this._proxy);
  
  void insert(String table, Map<String, Object?> values) {
    _operations.add(() => _proxy.insert(table, values));
  }
  
  void update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs}) {
    _operations.add(() => _proxy.update(table, values, where: where, whereArgs: whereArgs));
  }
  
  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    _operations.add(() => _proxy.delete(table, where: where, whereArgs: whereArgs));
  }
  
  Future<void> commit({bool? noResult, bool? continueOnError}) async {
    for (var op in _operations) {
      await op();
    }
  }
}
