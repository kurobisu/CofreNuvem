import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tutorial_provider.dart';
import '../utils/tutorial_content.dart';
import '../utils/tutorial_step.dart';

/// Botão de ajuda da AppBar. Dispara os passos **da tela onde está** e, na
/// primeira visita a essa tela, abre sozinho.
///
/// Mostrar automaticamente é por tela (flag própria no shared_preferences,
/// ver [TutorialSeenRepository]), em vez de um tour único no primeiro
/// acesso ao app: o usuário aprende cada tela quando chega nela, no
/// contexto em que a explicação faz sentido.
class TutorialButton extends ConsumerStatefulWidget {
  const TutorialButton({
    super.key,
    required this.screen,
    this.autoShow = true,
    this.stepsBuilder,
  });

  /// Identificador da tela (ver [TutorialScreens]).
  final String screen;

  /// Abrir sozinho na primeira visita a esta tela.
  final bool autoShow;

  /// Quando informado, substitui `tutorialStepsFor(screen)` -- usado por
  /// telas que montam os passos dinamicamente (ex.: CatalogoScreen, cujos
  /// passos trocam de aba e por isso precisam de um `TabController` que só
  /// existe naquela tela, não no conteúdo estático de tutorial_content.dart).
  /// Chamado de novo a cada vez que o tutorial inicia, pra sempre capturar
  /// o estado atual da tela.
  final List<TutorialStep> Function()? stepsBuilder;

  @override
  ConsumerState<TutorialButton> createState() => _TutorialButtonState();
}

class _TutorialButtonState extends ConsumerState<TutorialButton> {
  @override
  void initState() {
    super.initState();
    if (widget.autoShow) _maybeAutoStart();
  }

  Future<void> _maybeAutoStart() async {
    final repo = ref.read(tutorialSeenRepositoryProvider);
    if (await repo.hasSeen(widget.screen)) return;
    if (!mounted) return;
    // Espera a tela assentar (listas carregando, alvos ainda sem tamanho).
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await repo.markSeen(widget.screen);
    if (!mounted) return;
    _start();
  }

  void _start() {
    final steps = widget.stepsBuilder != null
        ? widget.stepsBuilder!()
        : tutorialStepsFor(widget.screen);
    if (steps.isEmpty) return;
    ref.read(tutorialProvider.notifier).start(steps);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: 'Como usar esta tela',
      onPressed: _start,
    );
  }
}
