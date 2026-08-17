import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/family_screen.dart';
import '../utils/tutorial_keys.dart';

/// Navigator global usado pelo tour guiado para empurrar/voltar rotas a
/// partir do controlador (fora da árvore de widgets de qualquer tela).
final GlobalKey<NavigatorState> tutorialNavigatorKey = GlobalKey<NavigatorState>();

/// Aba atual do MainScreen. Vive aqui (em vez de State local) para que o
/// tour guiado consiga trocar de aba (Dashboard <-> Compras) de fora.
class CurrentTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
}

final currentTabProvider = NotifierProvider<CurrentTabNotifier, int>(() => CurrentTabNotifier());

const _prefsCompletedKey = 'tutorial_completed';
const _prefsPendingStartKey = 'tutorial_pending_start';

class TutorialStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final String nextLabel;

  const TutorialStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.nextLabel = 'Próximo',
  });
}

final List<TutorialStep> tutorialSteps = [
  TutorialStep(
    targetKey: TutorialKeys.settingsContas,
    title: 'Contas & Métodos',
    description: 'Aqui você adiciona mais contas bancárias e configura cartões de crédito — dia de fechamento, dia de vencimento e limite.',
  ),
  TutorialStep(
    targetKey: TutorialKeys.accountsAddFab,
    title: 'Nova Conta ou Cartão',
    description: 'Toque aqui pra cadastrar uma nova conta bancária ou um cartão de crédito com os dados de fechamento, vencimento e limite.',
  ),
  TutorialStep(
    targetKey: TutorialKeys.settingsCategorias,
    title: 'Gerenciar Categorias',
    description: 'Organize suas despesas e receitas: crie categorias e subcategorias próprias, ou oculte/mostre as que já existem editando uma categoria.',
  ),
  TutorialStep(
    targetKey: TutorialKeys.categoriesAddFab,
    title: 'Nova Categoria',
    description: 'Você pode usar as categorias que já vêm prontas no app, ou tocar aqui pra criar categorias e subcategorias totalmente suas.',
  ),
  TutorialStep(
    targetKey: TutorialKeys.settingsFamilia,
    title: 'Membros da Família',
    description: 'Convide outras pessoas pra compartilhar a gestão financeira com você. Os dados de cada família ficam totalmente isolados — só quem você convidar, e que aceitar o convite, tem acesso.',
  ),
  TutorialStep(
    targetKey: TutorialKeys.familyInviteCard,
    title: 'Convidar Membros',
    description: 'Digite o e-mail de quem você quer convidar. A pessoa precisa já ter uma conta no CofreNuvem, e só entra na sua família se aceitar o convite.',
  ),
  TutorialStep(
    targetKey: TutorialKeys.dashboardFab,
    title: 'Lançar Despesas e Receitas',
    description: 'Use este botão pra registrar uma despesa (o que você gastou) ou receita (o que você recebeu). Dá pra marcar se já foi paga, parcelar, e vincular a uma conta ou cartão específico.',
  ),
  TutorialStep(
    targetKey: TutorialKeys.shoppingAddFab,
    title: 'Lista de Compras',
    description: 'Crie sua lista de compras aqui. Cada item pode ter preço e quantidade, e você marca o que já colocou no carrinho.',
  ),
  TutorialStep(
    targetKey: TutorialKeys.shoppingHistoryButton,
    title: 'Biblioteca de Produtos',
    description: 'Todo produto que você já comprou fica salvo aqui com o histórico de preços, pra você comparar e ver se o valor subiu ou baixou desde a última vez.',
    nextLabel: 'Concluir',
  ),
];

class TutorialState {
  final bool active;
  final int stepIndex;

  const TutorialState({this.active = false, this.stepIndex = 0});

  TutorialState copyWith({bool? active, int? stepIndex}) {
    return TutorialState(active: active ?? this.active, stepIndex: stepIndex ?? this.stepIndex);
  }
}

class TutorialController extends Notifier<TutorialState> {
  @override
  TutorialState build() => const TutorialState();

  void start() {
    ref.read(currentTabProvider.notifier).state = 3; // aba Ajustes
    state = const TutorialState(active: true, stepIndex: 0);
  }

  /// Chamado pelo botão "Próximo"/"Concluir" do balão. Executa a navegação
  /// necessária para chegar no próximo passo (empurrar rota, voltar, ou
  /// trocar de aba) e então avança o índice.
  void next() {
    final nav = tutorialNavigatorKey.currentState;
    if (nav == null) {
      finish();
      return;
    }

    switch (state.stepIndex) {
      case 0: // Ajustes -> Contas & Métodos
        nav.pushNamed('/manage_accounts');
        break;
      case 1: // Contas & Métodos -> volta pra Ajustes
        nav.pop();
        break;
      case 2: // Ajustes -> Gerenciar Categorias
        nav.pushNamed('/manage_categories');
        break;
      case 3: // Gerenciar Categorias -> volta pra Ajustes
        nav.pop();
        break;
      case 4: // Ajustes -> Membros da Família
        nav.push(MaterialPageRoute(builder: (_) => const FamilyScreen()));
        break;
      case 5: // Membros da Família -> volta pra Ajustes -> aba Dashboard
        nav.pop();
        ref.read(currentTabProvider.notifier).state = 0;
        break;
      case 6: // Dashboard -> aba Compras
        ref.read(currentTabProvider.notifier).state = 1;
        break;
      case 7: // Lista de Compras -> Biblioteca de Produtos (mesma tela)
        break;
      default:
        finish();
        return;
    }

    if (state.stepIndex + 1 >= tutorialSteps.length) {
      finish();
    } else {
      state = state.copyWith(stepIndex: state.stepIndex + 1);
    }
  }

  void skip() => finish();

  void finish() {
    state = const TutorialState(active: false, stepIndex: 0);
    ref.read(currentTabProvider.notifier).state = 0;
    SharedPreferences.getInstance().then((p) => p.setBool(_prefsCompletedKey, true));
  }
}

final tutorialProvider = NotifierProvider<TutorialController, TutorialState>(() => TutorialController());

/// Marca que o tour deve começar assim que o MainScreen for montado
/// (chamado ao final do onboarding, antes da navegação pra MainScreen).
Future<void> markTutorialPendingStart() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_prefsPendingStartKey, true);
}

/// Consome o flag de início pendente: retorna true (e limpa o flag) só na
/// primeira vez que o MainScreen checar após o onboarding.
Future<bool> consumeTutorialPendingStart() async {
  final prefs = await SharedPreferences.getInstance();
  final pending = prefs.getBool(_prefsPendingStartKey) ?? false;
  if (pending) await prefs.remove(_prefsPendingStartKey);
  return pending;
}
