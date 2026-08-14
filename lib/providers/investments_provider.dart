import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';

final investmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = SupabaseHelper.instance.client;
  final result = await supabase
      .from('investimentos')
      .select('*, usuarios(nome)')
      .filter('deleted_at', 'is', null)
      .or('status.eq.Ativo,status.is.null')
      .order('data_aporte', ascending: false);
      
  return result.map((r) {
    final double valInvestido = ((r['valor_investido'] ?? r['Valor_Investido'] ?? 0) as num).toDouble();
    final double valAtualizado = ((r['valor_atualizado'] ?? r['Valor_Atualizado'] ?? valInvestido) as num).toDouble();
    final String ativo = (r['ativo'] ?? r['Ativo'] ?? r['nome_ativo'] ?? r['Nome_Ativo'] ?? 'Sem nome').toString();
    final String id = (r['id'] ?? r['ID'] ?? '').toString();
    final String usuarioId = (r['usuario_id'] ?? r['Usuario_ID'] ?? '').toString();
    final String liquidez = (r['liquidez'] ?? r['Liquidez'] ?? 'Diária').toString();
    final String icone = (r['icone'] ?? r['Icone'] ?? 'savings').toString();
    final String status = (r['status'] ?? r['Status'] ?? 'Ativo').toString();
    final String dataAporte = (r['data_aporte'] ?? r['Data_Aporte'] ?? DateTime.now().toIso8601String()).toString();

    return {
      ...r,
      'ID': id,
      'id': id,
      'Ativo': ativo,
      'ativo': ativo,
      'Valor_Investido': valInvestido,
      'valor_investido': valInvestido,
      'Valor_Atualizado': valAtualizado,
      'valor_atualizado': valAtualizado,
      'Usuario_ID': usuarioId,
      'usuario_id': usuarioId,
      'Liquidez': liquidez,
      'liquidez': liquidez,
      'Icone': icone,
      'icone': icone,
      'Status': status,
      'status': status,
      'Data_Aporte': dataAporte,
      'data_aporte': dataAporte,
      'UsuarioNome': r['usuarios']?['nome'] ?? 'N/A'
    };
  }).toList();
});

final investmentHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = SupabaseHelper.instance.client;
  final result = await supabase
      .from('historico_rendimentos')
      .select('data, valor, investimento_id, investimentos(ativo, status)')
      .or('status.eq.Ativo,status.is.null', referencedTable: 'investimentos')
      .order('data', ascending: true);
      
  return result.map((r) {
    final double valor = ((r['valor'] ?? r['Valor'] ?? 0) as num).toDouble();
    final String data = (r['data'] ?? r['Data'] ?? '').toString();
    final String invId = (r['investimento_id'] ?? r['Investimento_ID'] ?? '').toString();
    final String ativo = (r['investimentos']?['ativo'] ?? r['investimentos']?['Ativo'] ?? '').toString();

    return {
      'Data': data,
      'data': data,
      'Valor': valor,
      'valor': valor,
      'Investimento_ID': invId,
      'investimento_id': invId,
      'Ativo': ativo,
      'ativo': ativo,
    };
  }).toList();
});
