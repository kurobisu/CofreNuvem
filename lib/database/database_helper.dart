import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static const _databaseName = "cofrenuvem_v2.db";
  static const _databaseVersion = 1; // V2 Clean Slate

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
  
  // Singleton instance
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  final _uuid = const Uuid();

  String generateId() => _uuid.v4();
  String get nowIso => DateTime.now().toUtc().toIso8601String();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath = await getDatabasesPath();
    String path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    // 1. Usuarios
    await db.execute('''
      CREATE TABLE $tableUsuarios (
        id TEXT PRIMARY KEY,
        auth_id TEXT NOT NULL,
        nome TEXT NOT NULL,
        pin_acesso TEXT,
        ordem INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 2. Contas_Bancarias
    await db.execute('''
      CREATE TABLE $tableContasBancarias (
        id TEXT PRIMARY KEY,
        auth_id TEXT NOT NULL,
        nome TEXT NOT NULL,
        codigo_banco TEXT,
        usuario_id TEXT REFERENCES $tableUsuarios (id) ON DELETE CASCADE,
        ordem INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 3. Metodos_Pagamento
    await db.execute('''
      CREATE TABLE $tableMetodosPagamento (
        id TEXT PRIMARY KEY,
        auth_id TEXT NOT NULL,
        nome TEXT NOT NULL,
        conta_id TEXT REFERENCES $tableContasBancarias (id) ON DELETE CASCADE,
        ordem INTEGER DEFAULT 0,
        tipo TEXT DEFAULT 'Outros',
        dia_fechamento INTEGER,
        dia_vencimento INTEGER,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 4. Categorias
    await db.execute('''
      CREATE TABLE $tableCategorias (
        id TEXT PRIMARY KEY,
        auth_id TEXT NOT NULL,
        nome TEXT NOT NULL,
        cor_hexadecimal TEXT NOT NULL,
        tipo TEXT NOT NULL DEFAULT 'Ambas',
        parent_id TEXT REFERENCES $tableCategorias (id) ON DELETE CASCADE,
        oculta INTEGER DEFAULT 0,
        ordem INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 5. Investimentos
    await db.execute('''
      CREATE TABLE $tableInvestimentos (
        id TEXT PRIMARY KEY,
        auth_id TEXT NOT NULL,
        ativo TEXT NOT NULL,
        data_aporte TEXT NOT NULL,
        valor_investido REAL NOT NULL,
        valor_atualizado REAL NOT NULL,
        liquidez TEXT NOT NULL,
        status TEXT DEFAULT 'Ativo',
        icone TEXT DEFAULT 'savings',
        usuario_id TEXT REFERENCES $tableUsuarios (id) ON DELETE CASCADE,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 6. Historico_Rendimentos
    await db.execute('''
      CREATE TABLE $tableHistoricoRendimentos (
        id TEXT PRIMARY KEY,
        auth_id TEXT NOT NULL,
        investimento_id TEXT REFERENCES $tableInvestimentos (id) ON DELETE CASCADE,
        data TEXT NOT NULL,
        valor REAL NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 7. Transacoes
    await db.execute('''
      CREATE TABLE $tableTransacoes (
        id TEXT PRIMARY KEY,
        auth_id TEXT NOT NULL,
        data TEXT NOT NULL,
        data_fatura TEXT,
        descricao TEXT NOT NULL,
        valor REAL NOT NULL,
        tipo TEXT NOT NULL,
        usuario_id TEXT REFERENCES $tableUsuarios (id) ON DELETE CASCADE,
        categoria_id TEXT REFERENCES $tableCategorias (id) ON DELETE CASCADE,
        conta_id TEXT REFERENCES $tableContasBancarias (id) ON DELETE CASCADE,
        metodo_id TEXT REFERENCES $tableMetodosPagamento (id) ON DELETE CASCADE,
        investimento_id TEXT REFERENCES $tableInvestimentos (id) ON DELETE SET NULL,
        parcela_atual INTEGER,
        parcela_total INTEGER,
        paga INTEGER DEFAULT 1,
        grupo_parcela_id TEXT,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 8. Lista de Compras
    await db.execute('''
      CREATE TABLE $tableListaCompras (
        id TEXT PRIMARY KEY,
        auth_id TEXT NOT NULL,
        nome TEXT NOT NULL,
        preco REAL,
        quantidade REAL,
        comprado INTEGER DEFAULT 0,
        transacao_id TEXT REFERENCES $tableTransacoes (id) ON DELETE CASCADE,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 9. Produtos
    await db.execute('''
      CREATE TABLE $tableProdutos (
        id TEXT PRIMARY KEY,
        auth_id TEXT NOT NULL,
        nome TEXT NOT NULL,
        categoria_id TEXT REFERENCES $tableCategorias (id) ON DELETE SET NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
  }

  // Wrapper for inserting to automatically generate ID, timestamp and auth_id
  Future<String> insert(String table, Map<String, dynamic> data, String authId) async {
    final db = await database;
    final id = data['id'] ?? generateId();
    final finalData = {
      ...data,
      'id': id,
      'auth_id': authId,
      'updated_at': nowIso,
    };
    await db.insert(table, finalData, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  // Wrapper for update
  Future<int> update(String table, Map<String, dynamic> data, String id) async {
    final db = await database;
    final finalData = {
      ...data,
      'updated_at': nowIso,
    };
    return await db.update(table, finalData, where: 'id = ?', whereArgs: [id]);
  }

  // Wrapper for soft delete
  Future<int> delete(String table, String id) async {
    final db = await database;
    return await db.update(table, {'deleted_at': nowIso, 'updated_at': nowIso}, where: 'id = ?', whereArgs: [id]);
  }

  Future<String> getDatabaseFilePath() async {
    String dbPath = await getDatabasesPath();
    return join(dbPath, _databaseName);
  }
}
