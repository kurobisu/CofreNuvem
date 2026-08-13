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

    final supabase = SupabaseHelper.instance.client;
    try {
      final tRes = await supabase.from('transacoes').select().eq('id', transactionId);
      if (tRes.isEmpty) return;
      
      final t = tRes.first;
      final String? invId = t['investimento_id']?.toString();
      
      if (invId != null && invId.isNotEmpty && invId != 'null') {
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
        
        final invRes = await supabase.from('investimentos').select().eq('id', invId);
        if (invRes.isNotEmpty) {
          final inv = invRes.first;
          final tipo = t['tipo']?.toString() ?? 'Despesa';
          final val = (t['valor'] as num?)?.toDouble() ?? 0.0;
          
          double atu = (inv['valor_atualizado'] as num?)?.toDouble() ?? 0.0;
          double invst = (inv['valor_investido'] as num?)?.toDouble() ?? 0.0;
          String status = inv['status']?.toString() ?? 'Ativo';
          
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

          await supabase.from('investimentos').update({
            'valor_atualizado': atu,
            'valor_investido': invst,
            'status': status,
          }).eq('id', invId);
          
          await supabase.from('historico_rendimentos').insert({
            'investimento_id': invId,
            'data': DateTime.now().toIso8601String().substring(0, 10),
            'valor': atu,
          });
        }
      }

      final String? transferId = t['transferencia_id']?.toString() ?? t['Transferencia_ID']?.toString();
      if (transferId != null && transferId.isNotEmpty && transferId != 'null') {
        debugPrint('Excluindo transferência vinculada: $transferId');
        await supabase
            .from('transacoes')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('transferencia_id', transferId);
      } else {
        await supabase
            .from('transacoes')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', transactionId);
      }
      
      if (context.mounted) {
        onSuccess();
      }
    } catch (e, stack) {
      debugPrint('Erro na exclusão: $e\\n$stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Falha ao excluir: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }
}
