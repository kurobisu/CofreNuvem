import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';

/// Family's total net worth: liquid balance (paid Receitas - Despesas)
/// plus the current value of all investments. Both halves are already
/// family-scoped by RLS, so this needs no explicit auth_id filtering.
final netWorthProvider = FutureProvider<double>((ref) async {
  final supabase = SupabaseHelper.instance.client;

  final List<dynamic> transacoesRaw = await supabase
      .from('transacoes')
      .select('valor, tipo, paga')
      .filter('deleted_at', 'is', null);

  double liquidBalance = 0.0;
  for (var raw in transacoesRaw) {
    final t = CaseInsensitiveMap(raw as Map<String, dynamic>);
    final paga = t['paga'];
    if (paga == 1 || paga == true) {
      final valor = ((t['valor'] ?? 0) as num).toDouble();
      final tipo = t['tipo'];
      liquidBalance += (tipo == 'Receita') ? valor : -valor;
    }
  }

  final List<dynamic> investimentosRaw = await supabase
      .from('investimentos')
      .select('valor_atualizado')
      .filter('deleted_at', 'is', null);

  double totalInvestments = 0.0;
  for (var raw in investimentosRaw) {
    final i = CaseInsensitiveMap(raw as Map<String, dynamic>);
    totalInvestments += ((i['valor_atualizado'] ?? 0) as num).toDouble();
  }

  return liquidBalance + totalInvestments;
});

final goalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = SupabaseHelper.instance.client;
  final List<dynamic> raw = await supabase
      .from(SupabaseHelper.tableMetas)
      .select()
      .filter('deleted_at', 'is', null)
      .order('ordem', ascending: true);

  return raw.map((e) => CaseInsensitiveMap(e as Map<String, dynamic>)).cast<Map<String, dynamic>>().toList();
});
