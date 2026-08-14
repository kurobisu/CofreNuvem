import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';

final investmentDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final db = await SupabaseHelper.instance.database;
  
  final invRes = await db.query(SupabaseHelper.tableInvestimentos, where: 'ID = ?', whereArgs: [id]);
  if (invRes.isEmpty) throw Exception('Investimento não encontrado');
  
  final rawInv = invRes.first;
  final double valInvestido = ((rawInv['valor_investido'] ?? rawInv['Valor_Investido'] ?? 0) as num).toDouble();
  final double valAtualizado = ((rawInv['valor_atualizado'] ?? rawInv['Valor_Atualizado'] ?? valInvestido) as num).toDouble();
  final String ativo = (rawInv['ativo'] ?? rawInv['Ativo'] ?? rawInv['nome_ativo'] ?? rawInv['Nome_Ativo'] ?? 'Sem nome').toString();
  final String invId = (rawInv['id'] ?? rawInv['ID'] ?? id).toString();
  final String usuarioId = (rawInv['usuario_id'] ?? rawInv['Usuario_ID'] ?? '').toString();
  final String liquidez = (rawInv['liquidez'] ?? rawInv['Liquidez'] ?? 'Diária').toString();
  final String icone = (rawInv['icone'] ?? rawInv['Icone'] ?? 'savings').toString();
  final String status = (rawInv['status'] ?? rawInv['Status'] ?? 'Ativo').toString();

  final Map<String, dynamic> cleanInvestment = {
    ...rawInv,
    'ID': invId,
    'id': invId,
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
  };
  
  final historyRes = await db.query(SupabaseHelper.tableHistoricoRendimentos, where: 'Investimento_ID = ?', whereArgs: [id], orderBy: 'Data ASC');
  final cleanHistory = historyRes.map((h) => {
    ...h,
    'Data': (h['data'] ?? h['Data'] ?? '').toString(),
    'Valor': ((h['valor'] ?? h['Valor'] ?? 0) as num).toDouble(),
    'Investimento_ID': (h['investimento_id'] ?? h['Investimento_ID'] ?? id).toString(),
  }).toList();
  
  final supabase = SupabaseHelper.instance.client;
  final transRaw = await supabase
      .from('transacoes')
      .select('*, contas_bancarias(nome)')
      .eq('investimento_id', id)
      .filter('deleted_at', 'is', null)
      .order('data', ascending: false);

  final transRes = transRaw.map((r) => {
    ...r,
    'ID': (r['id'] ?? r['ID'] ?? '').toString(),
    'Valor': ((r['valor'] ?? r['Valor'] ?? 0) as num).toDouble(),
    'Tipo': (r['tipo'] ?? r['Tipo'] ?? 'Despesa').toString(),
    'Data': (r['data'] ?? r['Data'] ?? '').toString(),
    'ContaNome': r['contas_bancarias']?['nome'] ?? 'Sem Conta',
  }).toList();
  
  return {
    'investment': cleanInvestment,
    'history': cleanHistory,
    'transactions': transRes,
  };
});
