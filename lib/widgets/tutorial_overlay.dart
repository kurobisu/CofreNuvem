import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tutorial_provider.dart';
import '../utils/tutorial_step.dart';

/// Camada montada uma única vez na raiz do app (via `MaterialApp.builder`)
/// que desenha o spotlight + balão do tutorial da tela ativa por cima de
/// qualquer tela, sempre que houver um tutorial em andamento.
class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  Rect? _targetRect;
  int? _measuredForIndex;
  bool _measuring = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Mede o widget-alvo depois do frame. O alvo pode ainda não estar montado
  /// (lista carregando, item fora da tela), então tenta algumas vezes antes
  /// de desistir e cair no cartão centralizado.
  Future<void> _measure(int index, GlobalKey key) async {
    if (_measuring) return;
    _measuring = true;

    BuildContext? targetContext;
    for (var tentativa = 0; tentativa < 40; tentativa++) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) {
        _measuring = false;
        return;
      }
      final tutorial = ref.read(tutorialProvider);
      if (!tutorial.active || tutorial.index != index) {
        _measuring = false;
        return;
      }
      final ctx = key.currentContext;
      final rb = ctx?.findRenderObject();
      if (rb is RenderBox && rb.attached && rb.hasSize) {
        targetContext = ctx;
        break;
      }
    }

    if (!mounted || targetContext == null || !targetContext.mounted) {
      _measuring = false;
      return;
    }

    // As telas do app ficam vivas em memória entre trocas de aba, então o
    // scroll de uma tela pode continuar de onde parou numa visita anterior.
    // Sem isso, o alvo pode estar scrollado pra fora da tela quando o
    // tutorial tenta destacá-lo.
    try {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.3,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 80));

    if (!mounted || !targetContext.mounted) {
      _measuring = false;
      return;
    }

    final rb = targetContext.findRenderObject();
    _measuring = false;
    if (rb is! RenderBox || !rb.attached || !rb.hasSize) return;

    final topLeft = rb.localToGlobal(Offset.zero);
    setState(() {
      _targetRect = topLeft & rb.size;
      _measuredForIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tutorial = ref.watch(tutorialProvider);
    final step = tutorial.currentStep;
    if (step == null) return const SizedBox.shrink();

    if (_measuredForIndex != tutorial.index) {
      _measuredForIndex = tutorial.index;
      _targetRect = null;
      // Roda antes da medição, na mesma leva de callbacks pós-frame: se o
      // passo troca de aba (CatalogoScreen), o alvo do próximo passo só
      // existe depois dessa troca.
      final onEnter = step.onEnter;
      if (onEnter != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onEnter());
      }
      final key = step.targetKey;
      if (key != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _measure(tutorial.index, key),
        );
      }
    }

    final controller = ref.read(tutorialProvider.notifier);
    final screenSize = MediaQuery.of(context).size;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // absorve toques fora do fluxo do tutorial
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) => CustomPaint(
                painter: _SpotlightPainter(
                  target: _targetRect,
                  pulse: _pulseController.value,
                  accentColor: accentColor,
                ),
              ),
            ),
          ),
        ),
        _TutorialBubble(
          step: step,
          targetRect: _targetRect,
          screenSize: screenSize,
          stepNumber: tutorial.index + 1,
          totalSteps: tutorial.steps.length,
          isLastStep: tutorial.isLastStep,
          onNext: controller.next,
          onPrevious: tutorial.index == 0 ? null : controller.previous,
          onSkip: controller.finish,
        ),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? target;
  final double pulse; // 0.0 -> 1.0 -> 0.0
  final Color accentColor;

  _SpotlightPainter({
    required this.target,
    required this.pulse,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (target == null) {
      canvas.drawPath(
        screenPath,
        Paint()..color = Colors.black.withOpacity(0.8),
      );
      return;
    }

    final holeRect = target!.inflate(10);
    final holeRRect = RRect.fromRectAndRadius(holeRect, const Radius.circular(16));

    // Escurece tudo, exceto a área do alvo -- que fica exatamente como está
    // na tela, sem nenhum tratamento por cima (nem escurecer, nem clarear
    // artificialmente).
    final holePath = Path()..addRRect(holeRRect);
    final scrimPath = Path.combine(PathOperation.difference, screenPath, holePath);
    canvas.drawPath(scrimPath, Paint()..color = Colors.black.withOpacity(0.8));

    // Brilho externo (glow) atrás da borda, pra reforçar o contorno mesmo
    // quando o conteúdo por trás já é escuro.
    final glowRRect = RRect.fromRectAndRadius(
      holeRect.inflate(2 + pulse * 4),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      glowRRect,
      Paint()
        ..color = accentColor.withOpacity(0.35 + pulse * 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Borda nítida, "pulsando" de espessura/brilho.
    canvas.drawRRect(
      holeRRect,
      Paint()
        ..color = Color.lerp(Colors.white, accentColor, 0.3)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + pulse * 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.target != target ||
      oldDelegate.pulse != pulse ||
      oldDelegate.accentColor != accentColor;
}

class _TutorialBubble extends StatelessWidget {
  final TutorialStep step;
  final Rect? targetRect;
  final Size screenSize;
  final int stepNumber;
  final int totalSteps;
  final bool isLastStep;
  final VoidCallback onNext;
  final VoidCallback? onPrevious;
  final VoidCallback onSkip;

  const _TutorialBubble({
    required this.step,
    required this.targetRect,
    required this.screenSize,
    required this.stepNumber,
    required this.totalSteps,
    required this.isLastStep,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    const margin = 16.0;
    const bubbleWidth = 320.0;
    const estimatedHeight = 220.0;
    final width = bubbleWidth > screenSize.width - margin * 2
        ? screenSize.width - margin * 2
        : bubbleWidth;

    final rect = targetRect;
    if (rect == null) {
      final top = (screenSize.height - estimatedHeight) / 2;
      final left = (screenSize.width - width) / 2;
      return Positioned(
        top: top,
        left: left,
        child: _bubbleCard(context, width),
      );
    }

    final spaceBelow = screenSize.height - rect.bottom;
    final placeBelow = spaceBelow > estimatedHeight || rect.top < estimatedHeight;

    double left = rect.center.dx - width / 2;
    if (left < margin) left = margin;
    if (left + width > screenSize.width - margin) {
      left = screenSize.width - margin - width;
    }

    return Positioned(
      left: left,
      child: placeBelow
          ? Padding(
              padding: EdgeInsets.only(top: rect.bottom + margin),
              child: _bubbleCard(context, width),
            )
          : Padding(
              padding: EdgeInsets.only(
                bottom: screenSize.height - rect.top + margin,
              ),
              child: _bubbleCard(context, width),
            ),
    );
  }

  Widget _bubbleCard(BuildContext context, double width) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$stepNumber DE $totalSteps',
              style: TextStyle(
                fontSize: 12,
                color: accentColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              step.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.description,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onPrevious != null)
                      TextButton(
                        onPressed: onPrevious,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        child: const Text('Voltar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    if (!isLastStep)
                      TextButton(
                        onPressed: onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        child: const Text('Pular', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: onNext,
                  icon: Icon(isLastStep ? Icons.check_circle : Icons.arrow_forward, size: 18),
                  label: Text(
                    isLastStep ? 'Concluir' : 'Próximo',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
