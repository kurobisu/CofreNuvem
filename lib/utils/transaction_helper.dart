import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';

class TransactionHelper {
  static Future<void> deleteTransactionWithConfirmation(
      BuildContext context, int transactionId, WidgetRef ref, VoidCallback onSuccess) async {
    
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

    final db = await DatabaseHelper.instance.database;
    final tRes = await db.query(DatabaseHelper.tableTransacoes, where: 'ID = ?', whereArgs: [transactionId]);
    if (tRes.isEmpty) return;
    
    final t = tRes.first;
    final int? invId = t['Investimento_ID'] as int?;
    
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
      
      final invRes = await db.query(DatabaseHelper.tableInvestimentos, where: 'ID = ?', whereArgs: [invId]);
      if (invRes.isNotEmpty) {
        final inv = invRes.first;
        final tipo = t['Tipo'] as String;
        final val = (t['Valor'] as num).toDouble();
        
        double atu = (inv['Valor_Atualizado'] as num).toDouble();
        double invst = (inv['Valor_Investido'] as num).toDouble();
        String status = inv['Status'] as String;
        
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

        await db.update(DatabaseHelper.tableInvestimentos, {
          'Valor_Atualizado': atu,
          'Valor_Investido': invst,
          'Status': status,
        }, where: 'ID = ?', whereArgs: [invId]);
        
        await db.insert(DatabaseHelper.tableHistoricoRendimentos, {
          'Investimento_ID': invId,
          'Data': DateTime.now().toIso8601String().substring(0, 10),
          'Valor': atu,
        });
      }
    }

    await db.delete(DatabaseHelper.tableTransacoes, where: 'ID = ?', whereArgs: [transactionId]);
    if (context.mounted) {
      onSuccess();
    }
  }
}
