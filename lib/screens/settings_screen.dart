import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/sync_service.dart';
import '../database/database_helper.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSyncing = false;
  bool _isExporting = false;

  Future<void> _forceSync() async {
    setState(() => _isSyncing = true);
    final syncService = ref.read(syncServiceProvider);
    
    // We force an upload
    await syncService.uploadLocalDatabase();
    
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronização com Google Drive concluída!')),
      );
    }
  }

  Future<void> _exportToCsv() async {
    setState(() => _isExporting = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final transacoes = await db.rawQuery('''
        SELECT t.ID, t.Data, t.Descricao, t.Valor, t.Tipo, u.Nome as Usuario, c.Nome as Categoria, cb.Nome || ' (' || mp.Nome || ')' as Conta
        FROM ${DatabaseHelper.tableTransacoes} t
        JOIN ${DatabaseHelper.tableUsuarios} u ON t.Usuario_ID = u.ID
        JOIN ${DatabaseHelper.tableCategorias} c ON t.Categoria_ID = c.ID
        LEFT JOIN ${DatabaseHelper.tableContasBancarias} cb ON t.Conta_ID = cb.ID
        LEFT JOIN ${DatabaseHelper.tableMetodosPagamento} mp ON t.Metodo_ID = mp.ID
      ''');

      List<List<dynamic>> rows = [];
      // Header
      rows.add(["ID", "Data", "Descrição", "Valor", "Tipo", "Usuário", "Categoria", "Conta/Método"]);
      
      // Data
      for (var row in transacoes) {
        rows.add([
          row['ID'],
          row['Data'],
          row['Descricao'],
          row['Valor'],
          row['Tipo'],
          row['Usuario'],
          row['Categoria'],
          row['Conta']
        ]);
      }

      String csvData = rows.map((row) => row.map((e) => '"\$e"').join(',')).join('\n');
      
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/cofrenuvem_export.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      if (mounted) {
        if (Platform.isWindows) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exportação Concluída'),
              content: Text('Seu arquivo foi salvo com sucesso em:\n\n\$path'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Process.run('explorer.exe', ['/select,', path]);
                    Navigator.pop(context);
                  },
                  child: const Text('Abrir Pasta'),
                )
              ],
            )
          );
        } else {
          // Mobile (Android/iOS)
          Share.shareXFiles([XFile(path)], text: 'Exportação CSV CofreNuvem');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar: \$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Cadastros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.category, color: Colors.orange),
                  title: const Text('Gerenciar Categorias'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pushNamed(context, '/manage_categories');
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.purple),
                  title: const Text('Contas & Métodos'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pushNamed(context, '/manage_accounts');
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.people, color: Colors.blue),
                  title: const Text('Gerenciar Usuários'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pushNamed(context, '/manage_users');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Interface', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Consumer(
              builder: (context, ref, child) {
                final limitAsync = ref.watch(settingsProvider);
                return ListTile(
                  leading: const Icon(Icons.dashboard_customize, color: Colors.teal),
                  title: const Text('Limite de Usuários no Dashboard'),
                  subtitle: const Text('Mostrar no painel principal'),
                  trailing: limitAsync.when(
                    data: (limit) => DropdownButton<String>(
                      value: limit,
                      underline: const SizedBox(),
                      items: ['1', '2', '3', '4', 'Ilimitado'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (val) {
                        if (val != null) ref.read(settingsProvider.notifier).setLimit(val);
                      }
                    ),
                    loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => const Icon(Icons.error),
                  ),
                );
              }
            )
          ),
          const SizedBox(height: 24),
          const Text('Nuvem & Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.cloud_sync, color: Colors.blue),
              title: const Text('Forçar Sincronização'),
              subtitle: const Text('Envia os dados locais para o Google Drive'),
              trailing: _isSyncing 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _isSyncing ? null : _forceSync,
            ),
          ),
          const SizedBox(height: 24),
          const Text('Dados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.table_view, color: Colors.green),
              title: const Text('Exportar para CSV'),
              subtitle: const Text('Gera arquivo compatível com Excel'),
              trailing: _isExporting 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _isExporting ? null : _exportToCsv,
            ),
          ),
        ],
      ),
    );
  }
}
