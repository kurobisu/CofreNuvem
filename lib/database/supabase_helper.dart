import 'dart:collection';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';

class CaseInsensitiveMap extends MapView<String, dynamic> {
  final Map<String, String> _lowerKeys;

  CaseInsensitiveMap(Map<String, dynamic> map)
      : _lowerKeys = { for (var k in map.keys) k.toLowerCase(): k },
        super(map);

  @override
  dynamic operator [](Object? key) {
    if (key is String) {
      final actualKey = _lowerKeys[key.toLowerCase()];
      if (actualKey != null) {
        return super[actualKey];
      }
    }
    return super[key];
  }
}

class SupabaseHelper {
  static final SupabaseHelper instance = SupabaseHelper._privateConstructor();
  SupabaseHelper._privateConstructor();

  final _client = Supabase.instance.client;

  // Tables
  static const tableUsuarios = 'usuarios';
  static const tableContasBancarias = 'contas_bancarias';
  static const tableMetodosPagamento = 'metodos_pagamento';
  static const tableCategorias = 'categorias';
  static const tableTransacoes = 'transacoes';
  static const tableInvestimentos = 'investimentos';
  static const tableHistoricoRendimentos = 'historico_rendimentos';
  static const tableListaCompras = 'lista_compras';
  static const tableProdutos = 'produtos';
  static const tableContasCompartilhadas = 'contas_compartilhadas';
  
  // O Proxy agora aponta para o SQLite Local! Offline-First!
  Future<OfflineSyncProxy> get database async {
    final db = await DatabaseHelper.instance.database;
    return OfflineSyncProxy(db, _client);
  }
}

class OfflineSyncProxy {
  final dynamic _db; // SQLite Database
  final SupabaseClient _client;
  
  OfflineSyncProxy(this._db, this._client);

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
    // Filtra automaticamente itens deletados (Soft Delete)
    String finalWhere = where != null ? '($where) AND deleted_at IS NULL' : 'deleted_at IS NULL';
    
    final result = await _db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: finalWhere,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset
    );
    
    return (result as List).map((e) => CaseInsensitiveMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final result = await _db.rawQuery(sql, arguments);
    return (result as List).map((e) => CaseInsensitiveMap(e as Map<String, dynamic>)).toList();
  }

  Future<String> insert(String table, Map<String, Object?> values, {dynamic conflictAlgorithm}) async {
    final lowerValues = values.map((k, v) => MapEntry(k.toLowerCase(), v));
    final authId = _client.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000000';
    return await DatabaseHelper.instance.insert(table, lowerValues, authId);
  }

  Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs}) async {
    final lowerValues = values.map((k, v) => MapEntry(k.toLowerCase(), v));
    
    // SQLite usually uses `where: 'id = ?'`. If whereArgs is provided, we use the first arg as ID.
    String id = '';
    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
       id = whereArgs.first.toString();
    } else if (lowerValues.containsKey('id')) {
       id = lowerValues['id'].toString();
    }

    if (id.isEmpty) return 0;
    
    return await DatabaseHelper.instance.update(table, lowerValues, id);
  }

  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    String id = '';
    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
       id = whereArgs.first.toString();
    }
    
    if (id.isEmpty) return 0;
    
    return await DatabaseHelper.instance.delete(table, id);
  }
  
  OfflineSyncBatch batch() {
    return OfflineSyncBatch(this);
  }
}

class OfflineSyncBatch {
  final OfflineSyncProxy _proxy;
  final List<Function> _operations = [];
  
  OfflineSyncBatch(this._proxy);
  
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
