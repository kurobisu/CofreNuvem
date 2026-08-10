import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static const _databaseName = "cofrenuvem.db";
  static const _databaseVersion = 5; // Bump para versão 5 (Ordenação)

  // Tables
  static const tableUsuarios = 'Usuarios';
  static const tableContasBancarias = 'Contas_Bancarias';
  static const tableContasCompartilhadas = 'Contas_Compartilhadas'; // Nova tabela
  static const tableMetodosPagamento = 'Metodos_Pagamento';
  static const tableCategorias = 'Categorias';
  static const tableTransacoes = 'Transacoes';
  static const tableInvestimentos = 'Investimentos';

  // Singleton instance
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for Windows/Linux/MacOS
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath = await getDatabasesPath();
    String path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS Transacoes');
      await db.execute('DROP TABLE IF EXISTS Contas_Compartilhadas');
      await db.execute('DROP TABLE IF EXISTS Contas_Bancarias');
      await db.execute('DROP TABLE IF EXISTS Metodos_Pagamento');
      await db.execute('DROP TABLE IF EXISTS Contas_Metodos');
      await db.execute('DROP TABLE IF EXISTS Categorias');
      await db.execute('DROP TABLE IF EXISTS Investimentos');
      await db.execute('DROP TABLE IF EXISTS Usuarios');
      
      // Cleanup das antigas bugadas caso ainda existam
      await db.execute('DROP TABLE IF EXISTS "\$tableUsuarios"');
      await db.execute('DROP TABLE IF EXISTS "\$tableContasBancarias"');
      await db.execute('DROP TABLE IF EXISTS "\$tableMetodosPagamento"');
      await db.execute('DROP TABLE IF EXISTS "\$tableCategorias"');
      await db.execute('DROP TABLE IF EXISTS "\$tableTransacoes"');
      await db.execute('DROP TABLE IF EXISTS "\$tableInvestimentos"');
      
      await _onCreate(db, newVersion);
    }
    
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE $tableUsuarios ADD COLUMN Ordem INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE $tableContasBancarias ADD COLUMN Ordem INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE $tableMetodosPagamento ADD COLUMN Ordem INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE $tableCategorias ADD COLUMN Ordem INTEGER DEFAULT 0');
    }
  }

  Future _onCreate(Database db, int version) async {
    // 1. Usuarios
    await db.execute('''
      CREATE TABLE $tableUsuarios (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Nome TEXT NOT NULL,
        PIN_Acesso TEXT,
        Ordem INTEGER DEFAULT 0
      )
    ''');

    // 2. Contas_Bancarias
    await db.execute('''
      CREATE TABLE $tableContasBancarias (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Nome TEXT NOT NULL,
        Codigo_Banco TEXT,
        Usuario_ID INTEGER,
        Ordem INTEGER DEFAULT 0,
        FOREIGN KEY (Usuario_ID) REFERENCES $tableUsuarios (ID) ON DELETE CASCADE
      )
    ''');

    // 2.1 Contas_Compartilhadas
    await db.execute('''
      CREATE TABLE $tableContasCompartilhadas (
        Conta_ID INTEGER NOT NULL,
        Usuario_ID INTEGER NOT NULL,
        PRIMARY KEY (Conta_ID, Usuario_ID),
        FOREIGN KEY (Conta_ID) REFERENCES $tableContasBancarias (ID) ON DELETE CASCADE,
        FOREIGN KEY (Usuario_ID) REFERENCES $tableUsuarios (ID) ON DELETE CASCADE
      )
    ''');

    // 2.2 Metodos_Pagamento
    await db.execute('''
      CREATE TABLE $tableMetodosPagamento (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Nome TEXT NOT NULL,
        Conta_ID INTEGER,
        Ordem INTEGER DEFAULT 0,
        FOREIGN KEY (Conta_ID) REFERENCES $tableContasBancarias (ID) ON DELETE CASCADE
      )
    ''');

    // 3. Categorias
    await db.execute('''
      CREATE TABLE $tableCategorias (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Nome TEXT NOT NULL,
        Cor_Hexadecimal TEXT NOT NULL,
        Tipo TEXT NOT NULL DEFAULT 'Ambas',
        Ordem INTEGER DEFAULT 0
      )
    ''');

    // 4. Transacoes
    await db.execute('''
      CREATE TABLE $tableTransacoes (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Data TEXT NOT NULL,
        Descricao TEXT NOT NULL,
        Valor REAL NOT NULL,
        Tipo TEXT NOT NULL,
        Usuario_ID INTEGER NOT NULL,
        Categoria_ID INTEGER NOT NULL,
        Conta_ID INTEGER NOT NULL,
        Metodo_ID INTEGER NOT NULL,
        Parcela_Atual INTEGER,
        Parcela_Total INTEGER,
        FOREIGN KEY (Usuario_ID) REFERENCES $tableUsuarios (ID) ON DELETE CASCADE,
        FOREIGN KEY (Categoria_ID) REFERENCES $tableCategorias (ID) ON DELETE CASCADE,
        FOREIGN KEY (Conta_ID) REFERENCES $tableContasBancarias (ID) ON DELETE CASCADE,
        FOREIGN KEY (Metodo_ID) REFERENCES $tableMetodosPagamento (ID) ON DELETE CASCADE
      )
    ''');

    // 5. Investimentos
    await db.execute('''
      CREATE TABLE $tableInvestimentos (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Ativo TEXT NOT NULL,
        Data_Aporte TEXT NOT NULL,
        Valor_Investido REAL NOT NULL,
        Valor_Atualizado REAL NOT NULL,
        Liquidez TEXT NOT NULL,
        Usuario_ID INTEGER NOT NULL,
        FOREIGN KEY (Usuario_ID) REFERENCES $tableUsuarios (ID) ON DELETE CASCADE
      )
    ''');

    await _seedData(db);
  }

  Future _seedData(Database db) async {
    // Seed Usuarios (Genérico para a versão Open-Source)
    await db.insert(tableUsuarios, {'ID': 1, 'Nome': 'Titular', 'PIN_Acesso': ''});

    // Seed Contas Bancárias (Carteira Física inicial)
    await db.insert(tableContasBancarias, {'ID': 1, 'Nome': 'Carteira Física', 'Codigo_Banco': '100', 'Usuario_ID': 1});

    // Seed Métodos de Pagamento
    await db.insert(tableMetodosPagamento, {'ID': 1, 'Nome': 'À Vista', 'Conta_ID': 1});

    // Seed Categorias
    final categorias = [
      {'Nome': 'Alimentação', 'Cor_Hexadecimal': '#FF5722', 'Tipo': 'Despesa'},
      {'Nome': 'Salário', 'Cor_Hexadecimal': '#4CAF50', 'Tipo': 'Receita'},
      {'Nome': 'Lazer', 'Cor_Hexadecimal': '#00BCD4', 'Tipo': 'Despesa'},
      {'Nome': 'Transferência', 'Cor_Hexadecimal': '#607D8B', 'Tipo': 'Ambas'},
    ];

    int catId = 1;
    for (var cat in categorias) {
      await db.insert(tableCategorias, {'ID': catId, 'Nome': cat['Nome'], 'Cor_Hexadecimal': cat['Cor_Hexadecimal'], 'Tipo': cat['Tipo']});
      catId++;
    }
  }

  // Helper method to get database path for sync purposes
  Future<String> getDatabaseFilePath() async {
    String dbPath = await getDatabasesPath();
    return join(dbPath, _databaseName);
  }
}
