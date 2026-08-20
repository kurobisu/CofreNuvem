import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/tutorial_step.dart';

/// Estado do tutorial em execução. Os passos são sempre os de **uma tela**:
/// não há tour global atravessando rotas -- cada tela ensina só o que está
/// nela, no momento em que o usuário chega lá (ver [TutorialButton] em
/// lib/widgets/tutorial_button.dart e o conteúdo em
/// lib/utils/tutorial_content.dart).
class TutorialState {
  const TutorialState({this.steps = const [], this.index = 0});

  final List<TutorialStep> steps;
  final int index;

  bool get active => steps.isNotEmpty;
  TutorialStep? get currentStep =>
      active && index < steps.length ? steps[index] : null;
  bool get isLastStep => index >= steps.length - 1;
}

class TutorialController extends Notifier<TutorialState> {
  @override
  TutorialState build() => const TutorialState();

  void start(List<TutorialStep> steps) {
    if (steps.isEmpty) return;
    state = TutorialState(steps: steps, index: 0);
  }

  void next() {
    if (!state.active) return;
    if (state.isLastStep) {
      finish();
      return;
    }
    state = TutorialState(steps: state.steps, index: state.index + 1);
  }

  void previous() {
    if (!state.active || state.index == 0) return;
    state = TutorialState(steps: state.steps, index: state.index - 1);
  }

  void finish() => state = const TutorialState();
}

final tutorialProvider = NotifierProvider<TutorialController, TutorialState>(
  TutorialController.new,
);

/// Marca em shared_preferences quais telas já mostraram o tutorial sozinhas,
/// pra ele aparecer automaticamente uma vez só por tela -- o botão de ajuda
/// na AppBar continua reabrindo quando o usuário quiser.
class TutorialSeenRepository {
  static String _key(String screen) => 'tutorial_${screen}_seen';

  Future<bool> hasSeen(String screen) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(screen)) ?? false;
  }

  Future<void> markSeen(String screen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(screen), true);
  }
}

final tutorialSeenRepositoryProvider = Provider<TutorialSeenRepository>(
  (ref) => TutorialSeenRepository(),
);
