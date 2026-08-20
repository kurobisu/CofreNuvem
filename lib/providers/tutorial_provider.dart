import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

/// Marca quais telas já mostraram o tutorial sozinhas, pra ele aparecer
/// automaticamente uma vez só por tela -- o botão de ajuda na AppBar
/// continua reabrindo quando o usuário quiser (ver [TutorialButton] em
/// lib/widgets/tutorial_button.dart, que só consulta isso pra decidir o
/// auto-show; o clique manual sempre reabre, visto ou não).
///
/// Guardado no `user_metadata` da conta no Supabase (não em
/// shared_preferences) -- de propósito: shared_preferences é por
/// dispositivo, então logar numa conta já usada num aparelho novo faria
/// todo tutorial já visto aparecer de novo. user_metadata acompanha a
/// conta e já vem carregado no login (não custa uma consulta extra pra
/// ler), então o "já visto" é o mesmo em qualquer dispositivo.
class TutorialSeenRepository {
  static const _metadataKey = 'tutoriais_vistos';

  List<String> _seenList() {
    final raw = Supabase.instance.client.auth.currentUser
        ?.userMetadata?[_metadataKey];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  Future<bool> hasSeen(String screen) async {
    return _seenList().contains(screen);
  }

  Future<void> markSeen(String screen) async {
    final atuais = _seenList();
    if (atuais.contains(screen)) return;

    // Faz merge manual em vez de mandar só {_metadataKey: [...]} -- outros
    // campos do user_metadata (ex.: 'nome', setado no cadastro em
    // login_screen.dart) não podem ser apagados por essa escrita.
    final metadataAtual = Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
    final novoMetadata = {
      ...metadataAtual,
      _metadataKey: [...atuais, screen],
    };
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: novoMetadata),
      );
    } catch (_) {
      // Falha de rede: na pior das hipóteses o tutorial aparece de novo na
      // próxima visita a esta tela -- nunca o contrário (sumir sem nunca
      // ter sido marcado como visto de verdade).
    }
  }
}

final tutorialSeenRepositoryProvider = Provider<TutorialSeenRepository>(
  (ref) => TutorialSeenRepository(),
);
