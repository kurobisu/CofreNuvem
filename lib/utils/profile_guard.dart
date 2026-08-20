import 'package:shared_preferences/shared_preferences.dart';
import '../database/supabase_helper.dart';

/// Evita o bug de um usuário com perfil já cadastrado ser mandado pra tela
/// de Onboarding -- que cria um Usuario/Conta/Cartão **novos**, duplicando
/// os dados de quem já usa o app (incidente real, ver
/// scripts/restore_antonio.sql e scripts/merge_duplicate_antonio.sql).
///
/// A causa raiz era `MainScreen._checkOnboarding` decidir "é usuário novo"
/// só porque a consulta a `usuarios` veio vazia -- e `OnlineProxy.query`
/// engole qualquer erro de rede/timeout e retorna `[]` também nesse caso,
/// então uma falha transiente (mais comum logo após abrir o app numa versão
/// nova) virava "manda pro onboarding".
///
/// Aqui: 1) uma vez confirmado que o perfil existe, isso fica guardado
/// localmente por usuário e a checagem nunca mais precisa de rede; 2) até
/// essa confirmação existir, qualquer erro de rede é tratado como "não sei
/// ainda" (não navega pra lugar nenhum), nunca como "é usuário novo".
class ProfileGuard {
  ProfileGuard._();

  static String _key(String userId) => 'has_profile_$userId';

  /// true = perfil já confirmado antes (leitura só local, sem rede).
  static Future<bool> knownToHaveProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId)) ?? false;
  }

  static Future<void> markHasProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
  }

  /// Consulta direta ao Supabase, fora do `OnlineProxy` (que trataria um
  /// erro de rede como "0 linhas"). Retorna `null` só quando a consulta
  /// falha -- nunca `false` por causa de um erro, apenas quando ela roda
  /// com sucesso e realmente confirma 0 linhas.
  static Future<bool?> hasProfileRemote() async {
    try {
      final row = await SupabaseHelper.instance.client
          .from(SupabaseHelper.tableUsuarios)
          .select('id')
          .filter('deleted_at', 'is', null)
          .limit(1)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return null;
    }
  }
}
