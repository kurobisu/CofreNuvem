import 'dart:collection';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  final client = Supabase.instance.client;

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

  Future<OnlineProxy> get database async {
    return OnlineProxy(client);
  }
}


class OnlineProxy {
  final SupabaseClient _client;
  
  OnlineProxy(this._client);

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
    try {
      dynamic q = _client.from(table).select();
      
      if (where != null) {
        final wLower = where.toLowerCase();
        if (wLower.contains('transacao_id is null')) {
          q = q.filter('transacao_id', 'is', null);
        }
        if (wLower.contains('parent_id is null')) {
          q = q.filter('parent_id', 'is', null);
        }
        
        if (whereArgs != null && whereArgs.isNotEmpty) {
          final firstArg = whereArgs[0] ?? '';
          if (wLower.contains('usuario_id =') || wLower.contains('usuario_id=')) {
            q = q.eq('usuario_id', firstArg);
          } else if (wLower.contains('transacao_id =') || wLower.contains('transacao_id=')) {
            q = q.eq('transacao_id', firstArg);
          } else if (wLower.contains('investimento_id =') || wLower.contains('investimento_id=')) {
            q = q.eq('investimento_id', firstArg);
          } else if (wLower.contains('categoria_id =') || wLower.contains('categoria_id=')) {
            q = q.eq('categoria_id', firstArg);
          } else if (wLower.contains('parent_id =') || wLower.contains('parent_id=')) {
            q = q.eq('parent_id', firstArg);
          } else if (wLower.contains('nome =') || wLower.contains('nome=')) {
            q = q.eq('nome', firstArg);
          } else if (wLower.contains('id =') || wLower.contains('id=')) {
            q = q.eq('id', firstArg);
          } else if (wLower.contains('transferencia_id =') || wLower.contains('transferencia_id=')) {
            q = q.eq('transferencia_id', firstArg);
          } else if (wLower.contains('tipo !=') || wLower.contains('tipo!=')) {
            q = q.neq('tipo', firstArg);
          }
        }

        if (wLower.contains('oculta = 0') || wLower.contains('oculta=0')) {
          q = q.eq('oculta', 0);
        }
      }
      
      // Filtro nativo de soft delete
      q = q.filter('deleted_at', 'is', null);

      if (orderBy != null) {
        final orders = orderBy.split(',');
        for (var order in orders) {
          final parts = order.trim().split(RegExp(r'\s+'));
          final colName = parts[0].toLowerCase();
          final isAsc = parts.length > 1 ? parts[1].toUpperCase() == 'ASC' : true;
          q = q.order(colName, ascending: isAsc);
        }
      }

      if (limit != null) q = q.limit(limit);

      final result = await q;
      return (result as List).map((e) => CaseInsensitiveMap(e as Map<String, dynamic>)).cast<Map<String, dynamic>>().toList();
    } catch (e) {
      print('Erro no OnlineProxy.query ($table): $e');
      return [];
    }
  }

  Future<String> insert(String table, Map<String, Object?> values) async {
    final lowerValues = values.map((k, v) => MapEntry(k.toLowerCase(), v));
    lowerValues['auth_id'] = _client.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000000';
    final res = await _client.from(table).insert(lowerValues).select('id').single();
    return res['id'].toString();
  }

  Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs}) async {
    final lowerValues = values.map((k, v) => MapEntry(k.toLowerCase(), v));
    lowerValues['updated_at'] = DateTime.now().toUtc().toIso8601String();
    
    String id = '';
    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
       id = whereArgs.first.toString();
    } else if (lowerValues.containsKey('id')) {
       id = lowerValues['id'].toString();
    }

    if (id.isEmpty) return 0;
    
    await _client.from(table).update(lowerValues).eq('id', id);
    return 1;
  }

  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    String id = '';
    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
       id = whereArgs.first.toString();
    }
    
    if (id.isEmpty) return 0;
    
    await _client.from(table).update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    return 1;
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    throw Exception('rawQuery não suportado em OnlineProxy. Migre para consultas diretas Supabase.');
  }
}
