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
      
  return result.map((r) => {
    ...r,
    'UsuarioNome': r['usuarios']?['nome'] ?? 'N/A'
  }).toList();
});

final investmentHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = SupabaseHelper.instance.client;
  final result = await supabase
      .from('historico_rendimentos')
      .select('data, valor, investimento_id, investimentos(ativo, status)')
      .or('status.eq.Ativo,status.is.null', referencedTable: 'investimentos')
      .order('data', ascending: true);
      
  return result.map((r) => {
    'Data': r['data'],
    'Valor': r['valor'],
    'Investimento_ID': r['investimento_id'],
    'Ativo': r['investimentos']?['ativo'] ?? '',
  }).toList();
});
