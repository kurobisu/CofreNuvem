import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class SyncManager {
  static final SyncManager instance = SyncManager._();
  SyncManager._();

  final _supabase = Supabase.instance.client;
  final _dbHelper = DatabaseHelper.instance;

  static const _lastSyncKey = 'last_sync_timestamp';

  Future<void> sync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? lastSync = prefs.getString(_lastSyncKey);
      
      // Se não houver último sync, puxamos de 2000
      final syncTime = lastSync ?? '2000-01-01T00:00:00.000Z';
      
      // O processo de sincronização bidirecional Offline-First usando Last Write Wins (LWW):
      // 1. PULL: Baixa tudo que foi atualizado no servidor desde o último sync e injeta no SQLite.
      await _pullChanges(syncTime);
      
      // 2. PUSH: Envia para o servidor tudo que foi alterado localmente desde o último sync.
      await _pushChanges(syncTime);
      
      // Atualiza o timestamp do último sync para agora
      await prefs.setString(_lastSyncKey, DateTime.now().toUtc().toIso8601String());
      
    } catch (e) {
      print('Erro na sincronização offline: $e');
    }
  }

  Future<void> _pullChanges(String lastSyncTime) async {
    final db = await _dbHelper.database;
    final tables = [
      DatabaseHelper.tableUsuarios,
      DatabaseHelper.tableCategorias,
      DatabaseHelper.tableContasBancarias,
      DatabaseHelper.tableMetodosPagamento,
      DatabaseHelper.tableInvestimentos,
      DatabaseHelper.tableHistoricoRendimentos,
      DatabaseHelper.tableTransacoes,
      DatabaseHelper.tableListaCompras,
    ];

    for (var table in tables) {
      // Baixa do Supabase (A regra de RLS das famílias já filtra os dados que temos acesso!)
      final List<dynamic> remoteData = await _supabase
          .from(table)
          .select()
          .gt('updated_at', lastSyncTime);
          
      for (var row in remoteData) {
        // Upsert (substitui local pelo do servidor se existir)
        await db.insert(table, row as Map<String, dynamic>, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  Future<void> _pushChanges(String lastSyncTime) async {
    final db = await _dbHelper.database;
    final tables = [
      DatabaseHelper.tableUsuarios,
      DatabaseHelper.tableCategorias,
      DatabaseHelper.tableContasBancarias,
      DatabaseHelper.tableMetodosPagamento,
      DatabaseHelper.tableInvestimentos,
      DatabaseHelper.tableHistoricoRendimentos,
      DatabaseHelper.tableTransacoes,
      DatabaseHelper.tableListaCompras,
    ];

    for (var table in tables) {
      // Pega tudo que mudou localmente e que ainda não foi enviado (ou seja, update_at local > lastSyncTime)
      final localData = await db.query(table, where: 'updated_at > ?', whereArgs: [lastSyncTime]);
      
      if (localData.isNotEmpty) {
        // Envia para o Supabase via Upsert
        await _supabase.from(table).upsert(localData);
      }
    }
  }
  
  // Realtime Listen - Escuta mudanças ativamente enquanto o app está aberto online
  void listenToRealtimeUpdates(Function onDataChanged) {
    _supabase.channel('public:*').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      callback: (payload) async {
        // Sempre que o Supabase notificar uma mudança (ex: a esposa alterou algo), fazemos um sync rápido
        await sync();
        onDataChanged(); // Atualiza a tela
      }
    ).subscribe();
  }
}
