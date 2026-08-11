import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static const _databaseName = "cofrenuvem.db";
  static const _databaseVersion = 12; // Bump para versão 12 (Detalhes Investimentos e Soft Delete)

  // Tables
  static const tableUsuarios = 'Usuarios';
  static const tableContasBancarias = 'Contas_Bancarias';
  static const tableContasCompartilhadas = 'Contas_Compartilhadas'; // Nova tabela
  static const tableMetodosPagamento = 'Metodos_Pagamento';
  static const tableCategorias = 'Categorias';
  static const tableTransacoes = 'Transacoes';
  static const tableInvestimentos = 'Investimentos';
  static const tableHistoricoRendimentos = 'Historico_Rendimentos';
  static const tableListaCompras = 'Lista_Compras';
  static const tableProdutos = 'Produtos';

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
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        // Limpar transações e contas órfãs (quando usuários/contas foram deletados antes do ON DELETE CASCADE funcionar)
        await db.execute('DELETE FROM $tableTransacoes WHERE Usuario_ID NOT IN (SELECT ID FROM $tableUsuarios)');
        await db.execute('DELETE FROM $tableTransacoes WHERE Conta_ID NOT IN (SELECT ID FROM $tableContasBancarias)');
        await db.execute('DELETE FROM $tableContasBancarias WHERE Usuario_ID NOT IN (SELECT ID FROM $tableUsuarios)');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // A partir da versão 4, as migrações serão feitas de forma segura (Safe Migrations)
    // Usando ALTER TABLE para garantir que os dados não sejam perdidos.
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE $tableUsuarios ADD COLUMN Ordem INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE $tableContasBancarias ADD COLUMN Ordem INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE $tableMetodosPagamento ADD COLUMN Ordem INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE $tableCategorias ADD COLUMN Ordem INTEGER DEFAULT 0');
    }
    
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE $tableTransacoes ADD COLUMN Paga INTEGER DEFAULT 1');
      await db.execute('''
        CREATE TABLE $tableListaCompras (
          ID INTEGER PRIMARY KEY AUTOINCREMENT,
          Nome TEXT NOT NULL,
          Preco REAL,
          Quantidade REAL,
          Comprado INTEGER DEFAULT 0
        )
      ''');
    }
    
    if (oldVersion < 7) {
      // Vínculo da lista de compras com a transação
      await db.execute('ALTER TABLE $tableListaCompras ADD COLUMN Transacao_ID INTEGER REFERENCES $tableTransacoes (ID) ON DELETE CASCADE');
    }

    if (oldVersion < 8) {
      // Faturas e Grupo de Parcelas
      await db.execute('ALTER TABLE $tableMetodosPagamento ADD COLUMN Tipo TEXT DEFAULT "Outros"');
      await db.execute('ALTER TABLE $tableMetodosPagamento ADD COLUMN Dia_Fechamento INTEGER');
      await db.execute('ALTER TABLE $tableMetodosPagamento ADD COLUMN Dia_Vencimento INTEGER');
      await db.execute('ALTER TABLE $tableTransacoes ADD COLUMN Grupo_Parcela_ID TEXT');
    }

    if (oldVersion < 9) {
      // Tabela de Produtos (Biblioteca)
      await db.execute('''
        CREATE TABLE $tableProdutos (
          ID INTEGER PRIMARY KEY AUTOINCREMENT,
          Nome TEXT UNIQUE NOT NULL,
          Categoria_ID INTEGER,
          FOREIGN KEY (Categoria_ID) REFERENCES $tableCategorias (ID) ON DELETE SET NULL
        )
      ''');
      
      // Seed da tabela Produtos a partir da Lista de Compras
      await db.execute('''
        INSERT OR IGNORE INTO $tableProdutos (Nome)
        SELECT DISTINCT Nome FROM $tableListaCompras WHERE Transacao_ID IS NOT NULL
      ''');
    }

    if (oldVersion < 10) {
      // Add columns for sub-categories
      await db.execute('ALTER TABLE $tableCategorias ADD COLUMN Parent_ID INTEGER');
      await db.execute('ALTER TABLE $tableCategorias ADD COLUMN Oculta INTEGER DEFAULT 0');

      // V10 Seed Standard Categories
      final categoriasPai = [
        {'Nome': 'Moradia', 'Cor_Hexadecimal': '#795548', 'Tipo': 'Despesa'},
        {'Nome': 'Saúde', 'Cor_Hexadecimal': '#E91E63', 'Tipo': 'Despesa'},
        {'Nome': 'Transporte', 'Cor_Hexadecimal': '#3F51B5', 'Tipo': 'Despesa'},
        {'Nome': 'Outros', 'Cor_Hexadecimal': '#9E9E9E', 'Tipo': 'Ambas'},
      ];

      for (var cat in categoriasPai) {
        final res = await db.query(tableCategorias, where: 'Nome = ?', whereArgs: [cat['Nome']]);
        int parentId;
        if (res.isEmpty) {
          parentId = await db.insert(tableCategorias, {'Nome': cat['Nome'], 'Cor_Hexadecimal': cat['Cor_Hexadecimal'], 'Tipo': cat['Tipo']});
        } else {
          parentId = res.first['ID'] as int;
        }

        if (cat['Nome'] == 'Moradia') {
          await _insertSub(db, parentId, 'Aluguel', '#8D6E63');
          await _insertSub(db, parentId, 'Contas (Água/Luz)', '#A1887F');
          await _insertSub(db, parentId, 'Internet', '#BCAAA4');
        } else if (cat['Nome'] == 'Saúde') {
          await _insertSub(db, parentId, 'Farmácia', '#F06292');
          await _insertSub(db, parentId, 'Médicos', '#F48FB1');
          await _insertSub(db, parentId, 'Higiene Pessoal', '#F8BBD0');
        } else if (cat['Nome'] == 'Transporte') {
          await _insertSub(db, parentId, 'Combustível', '#5C6BC0');
          await _insertSub(db, parentId, 'Aplicativos', '#7986CB');
        }
      }

      // Convert existing 'Alimentação' to parent and add subs
      final alimRes = await db.query(tableCategorias, where: 'Nome = ?', whereArgs: ['Alimentação']);
      if (alimRes.isNotEmpty) {
        int alimId = alimRes.first['ID'] as int;
        await _insertSub(db, alimId, 'Mercado', '#FF7043');
        await _insertSub(db, alimId, 'Restaurante', '#FF8A65');
        await _insertSub(db, alimId, 'Lanches', '#FFAB91');
      }
    }

    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableHistoricoRendimentos (
          ID INTEGER PRIMARY KEY AUTOINCREMENT,
          Investimento_ID INTEGER NOT NULL,
          Data TEXT NOT NULL,
          Valor REAL NOT NULL,
          FOREIGN KEY (Investimento_ID) REFERENCES $tableInvestimentos (ID) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 12) {
      await db.execute('ALTER TABLE $tableInvestimentos ADD COLUMN Status TEXT DEFAULT "Ativo"');
      await db.execute('ALTER TABLE $tableInvestimentos ADD COLUMN Icone TEXT DEFAULT "savings"');
      await db.execute('ALTER TABLE $tableTransacoes ADD COLUMN Investimento_ID INTEGER REFERENCES $tableInvestimentos (ID) ON DELETE SET NULL');
    }
  }

  Future<void> _insertSub(Database db, int parentId, String nome, String cor) async {
    final res = await db.query(tableCategorias, where: 'Nome = ? AND Parent_ID = ?', whereArgs: [nome, parentId]);
    if (res.isEmpty) {
      await db.insert(tableCategorias, {
        'Nome': nome,
        'Cor_Hexadecimal': cor,
        'Tipo': 'Despesa',
        'Parent_ID': parentId
      });
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
        Tipo TEXT DEFAULT 'Outros',
        Dia_Fechamento INTEGER,
        Dia_Vencimento INTEGER,
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
        Parent_ID INTEGER,
        Oculta INTEGER DEFAULT 0,
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
        Paga INTEGER DEFAULT 1,
        Grupo_Parcela_ID TEXT,
        Investimento_ID INTEGER,
        FOREIGN KEY (Usuario_ID) REFERENCES $tableUsuarios (ID) ON DELETE CASCADE,
        FOREIGN KEY (Categoria_ID) REFERENCES $tableCategorias (ID) ON DELETE CASCADE,
        FOREIGN KEY (Conta_ID) REFERENCES $tableContasBancarias (ID) ON DELETE CASCADE,
        FOREIGN KEY (Metodo_ID) REFERENCES $tableMetodosPagamento (ID) ON DELETE CASCADE,
        FOREIGN KEY (Investimento_ID) REFERENCES $tableInvestimentos (ID) ON DELETE SET NULL
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
        Status TEXT DEFAULT 'Ativo',
        Icone TEXT DEFAULT 'savings',
        Usuario_ID INTEGER NOT NULL,
        FOREIGN KEY (Usuario_ID) REFERENCES $tableUsuarios (ID) ON DELETE CASCADE
      )
    ''');

    // 5.1 Historico de Rendimentos
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableHistoricoRendimentos (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Investimento_ID INTEGER NOT NULL,
        Data TEXT NOT NULL,
        Valor REAL NOT NULL,
        FOREIGN KEY (Investimento_ID) REFERENCES $tableInvestimentos (ID) ON DELETE CASCADE
      )
    ''');

    // 6. Lista de Compras
    await db.execute('''
      CREATE TABLE $tableListaCompras (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Nome TEXT NOT NULL,
        Preco REAL,
        Quantidade REAL,
        Comprado INTEGER DEFAULT 0,
        Transacao_ID INTEGER REFERENCES $tableTransacoes (ID) ON DELETE CASCADE
      )
    ''');

    // 7. Produtos
    await db.execute('''
      CREATE TABLE $tableProdutos (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Nome TEXT UNIQUE NOT NULL,
        Categoria_ID INTEGER,
        FOREIGN KEY (Categoria_ID) REFERENCES $tableCategorias (ID) ON DELETE SET NULL
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

    // Seed Categorias Pai
    final categoriasPai = [
      {'Nome': 'Alimentação', 'Cor_Hexadecimal': '#FF5722', 'Tipo': 'Despesa'},
      {'Nome': 'Moradia', 'Cor_Hexadecimal': '#795548', 'Tipo': 'Despesa'},
      {'Nome': 'Saúde', 'Cor_Hexadecimal': '#E91E63', 'Tipo': 'Despesa'},
      {'Nome': 'Transporte', 'Cor_Hexadecimal': '#3F51B5', 'Tipo': 'Despesa'},
      {'Nome': 'Lazer', 'Cor_Hexadecimal': '#00BCD4', 'Tipo': 'Despesa'},
      {'Nome': 'Salário', 'Cor_Hexadecimal': '#4CAF50', 'Tipo': 'Receita'},
      {'Nome': 'Transferência', 'Cor_Hexadecimal': '#607D8B', 'Tipo': 'Ambas'},
      {'Nome': 'Outros', 'Cor_Hexadecimal': '#9E9E9E', 'Tipo': 'Ambas'},
    ];

    for (var cat in categoriasPai) {
      int parentId = await db.insert(tableCategorias, {'Nome': cat['Nome'], 'Cor_Hexadecimal': cat['Cor_Hexadecimal'], 'Tipo': cat['Tipo']});
      
      if (cat['Nome'] == 'Alimentação') {
        await _insertSub(db, parentId, 'Mercado', '#FF7043');
        await _insertSub(db, parentId, 'Restaurante', '#FF8A65');
        await _insertSub(db, parentId, 'Lanches', '#FFAB91');
      } else if (cat['Nome'] == 'Moradia') {
        await _insertSub(db, parentId, 'Aluguel', '#8D6E63');
        await _insertSub(db, parentId, 'Contas (Água/Luz)', '#A1887F');
        await _insertSub(db, parentId, 'Internet', '#BCAAA4');
      } else if (cat['Nome'] == 'Saúde') {
        await _insertSub(db, parentId, 'Farmácia', '#F06292');
        await _insertSub(db, parentId, 'Médicos', '#F48FB1');
        await _insertSub(db, parentId, 'Higiene Pessoal', '#F8BBD0');
      } else if (cat['Nome'] == 'Transporte') {
        await _insertSub(db, parentId, 'Combustível', '#5C6BC0');
        await _insertSub(db, parentId, 'Aplicativos', '#7986CB');
      }
    }
  }

  // Helper method to get database path for sync purposes
  Future<String> getDatabaseFilePath() async {
    String dbPath = await getDatabasesPath();
    return join(dbPath, _databaseName);
  }
}
