import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';

class TransactionHelper {
  static Future<void> deleteTransactionWithConfirmation(
      BuildContext context, String transactionId, WidgetRef ref, VoidCallback onSuccess) async {
    
    // Alerta 1
    final confirmar1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Transação'),
        content: const Text('Você está prestes a excluir esta transação. Deseja continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sim', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar1 != true) return;
    if (!context.mounted) return;

    final db = await SupabaseHelper.instance.database;
    final tRes = await db.query(SupabaseHelper.tableTransacoes, where: 'ID = ?', whereArgs: [transactionId]);
    if (tRes.isEmpty) return;
    
    final t = tRes.first;
    final int? invId = t['investimento_id'] as int?;
    
    if (invId != null) {
      // Alerta 2 Rigoroso
      final confirmar2 = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ ALERTA RIGOROSO', style: TextStyle(color: Colors.red)),
          content: const Text('Esta transação faz parte de um Investimento.\nExcluí-la irá alterar os saldos do seu investimento e isso é irreversível.\nDeseja REALMENTE continuar?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true), 
              child: const Text('EXCLUIR ASSIM MESMO')
            ),
          ],
        ),
      );

      if (confirmar2 != true) return;
      
      final invRes = await db.query(SupabaseHelper.tableInvestimentos, where: 'ID = ?', whereArgs: [invId]);
      if (invRes.isNotEmpty) {
        final inv = invRes.first;
        final tipo = t['tipo'] as String;
        final val = (t['valor'] as num).toDouble();
        
        double atu = (inv['valor_atualizado'] as num).toDouble();
        double invst = (inv['valor_investido'] as num).toDouble();
        String status = inv['status'] as String;
        
        if (tipo == 'Despesa') {
          // Aporte sendo apagado -> reduzir
          atu -= val;
          invst -= val;
          if (atu <= 0) {
            atu = 0;
            invst = 0;
            status = 'Resgatado';
          }
        } else if (tipo == 'Receita') {
          // Resgate sendo apagado -> restaurar
          atu += val;
          invst += val;
          if (status == 'Resgatado') {
            status = 'Ativo';
          }
        }

        await db.update(SupabaseHelper.tableInvestimentos, {
          'Valor_Atualizado': atu,
          'Valor_Investido': invst,
          'Status': status,
        }, where: 'ID = ?', whereArgs: [invId]);
        
        await db.insert(SupabaseHelper.tableHistoricoRendimentos, {
          'Investimento_ID': invId,
          'Data': DateTime.now().toIso8601String().substring(0, 10),
          'Valor': atu,
        });
      }
    }

    await db.delete(SupabaseHelper.tableTransacoes, where: 'ID = ?', whereArgs: [transactionId]);
    if (context.mounted) {
      onSuccess();
    }
  }
}
