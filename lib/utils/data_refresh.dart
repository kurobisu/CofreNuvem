import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../providers/investments_provider.dart';
import '../providers/investment_details_provider.dart';
import '../providers/goals_provider.dart';

/// Invalida todos os providers de dados que buscam informação da conta
/// logada (dashboard, investimentos, metas). Usado tanto na troca de
/// usuário (login/logout) quanto no botão "Forçar Sincronização", pra
/// garantir que a tela busque tudo de novo do zero.
void invalidateAllDataProviders(WidgetRef ref) {
  ref.invalidate(dashboardDataProvider);
  ref.invalidate(investmentsProvider);
  ref.invalidate(investmentHistoryProvider);
  ref.invalidate(investmentDetailsProvider);
  ref.invalidate(goalsProvider);
  ref.invalidate(netWorthProvider);
}
