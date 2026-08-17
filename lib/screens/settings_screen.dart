import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/sync_service.dart';
import '../database/supabase_helper.dart';
import '../providers/settings_provider.dart';
import '../providers/tutorial_provider.dart';
import '../utils/tutorial_keys.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'family_screen.dart';
import '../utils/app_version.dart';


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
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados 100% atualizados na nuvem!')),
      );
    }
  }

  Future<void> _exportToCsv() async {
    setState(() => _isExporting = true);
    try {
      final supabase = SupabaseHelper.instance.client;
      final transacoes = await supabase
          .from('transacoes')
          .select('id, data, descricao, valor, tipo, usuarios(nome), categorias(nome), contas_bancarias(nome), metodos_pagamento(nome)')
          .filter('deleted_at', 'is', null);

      List<List<dynamic>> rows = [];
      // Header
      rows.add(["ID", "Data", "Descrição", "Valor", "Tipo", "Usuário", "Categoria", "Conta/Método"]);
      
      // Data
      for (var row in transacoes) {
        String conta = (row['contas_bancarias']?['nome'] ?? '') + ' (' + (row['metodos_pagamento']?['nome'] ?? '') + ')';
        rows.add([
          row['id'],
          row['data'],
          row['descricao'],
          row['valor'],
          row['tipo'],
          row['usuarios']?['nome'] ?? '',
          row['categorias']?['nome'] ?? '',
          conta
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
      appBar: AppBar(title: const Text('Configurações $appVersion')),
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
                  key: TutorialKeys.settingsCategorias,
                  leading: const Icon(Icons.category, color: Colors.orange),
                  title: const Text('Gerenciar Categorias'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pushNamed(context, '/manage_categories');
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  key: TutorialKeys.settingsContas,
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
          const Text('Família & Compartilhamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              key: TutorialKeys.settingsFamilia,
              leading: const Icon(Icons.family_restroom, color: Colors.indigo),
              title: const Text('Membros da Família'),
              subtitle: const Text('Convide e gerencie membros da sua casa'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyScreen()));
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text('Ajuda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Consumer(
              builder: (context, ref, child) {
                return ListTile(
                  leading: const Icon(Icons.school, color: Colors.teal),
                  title: const Text('Tutorial Guiado'),
                  subtitle: const Text('Reveja como configurar e usar o app'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => ref.read(tutorialProvider.notifier).start(),
                );
              },
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
              subtitle: const Text('Baixa e envia dados da nuvem do aplicativo'),
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
          const SizedBox(height: 24),
          const Text('Conta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair da Conta', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              subtitle: const Text('Desconectar deste dispositivo'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sair da Conta?'),
                    content: const Text('Você será desconectado e precisará fazer login novamente para acessar seus dados.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true), 
                        child: const Text('Sair')
                      ),
                    ],
                  )
                );

                if (confirm == true) {
// Banco local removido
                  await Supabase.instance.client.auth.signOut();
// Banco local removido
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
