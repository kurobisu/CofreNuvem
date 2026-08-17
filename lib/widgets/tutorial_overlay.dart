import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tutorial_provider.dart';

/// Camada montada uma única vez na raiz do app (via `MaterialApp.builder`)
/// que desenha o spotlight + balão do tour guiado por cima de qualquer tela,
/// sempre que o tutorial estiver ativo.
class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay> with SingleTickerProviderStateMixin {
  Rect? _targetRect;
  int? _measuredForStep;
  bool _measuring = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _measure(int stepIndex) async {
    if (_measuring) return;
    _measuring = true;

    BuildContext? targetContext;
    for (int i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) {
        _measuring = false;
        return;
      }
      final ctx = tutorialSteps[stepIndex].targetKey.currentContext;
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

    // As telas do app ficam vivas em memória (MainScreen mantém as páginas
    // fixas entre trocas de aba), então o scroll de uma tela pode continuar
    // de onde parou numa visita anterior. Sem isso, o alvo pode estar
    // scrollado pra fora da tela quando o tutorial tenta destacá-lo.
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
      _measuredForStep = stepIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tutorial = ref.watch(tutorialProvider);

    if (!tutorial.active) {
      return const SizedBox.shrink();
    }

    if (_measuredForStep != tutorial.stepIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure(tutorial.stepIndex));
      return const SizedBox.shrink();
    }

    final step = tutorialSteps[tutorial.stepIndex];
    final rect = _targetRect!;
    final screenSize = MediaQuery.of(context).size;
    final isLastStep = tutorial.stepIndex == tutorialSteps.length - 1;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // absorve toques fora do fluxo do tour
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) => CustomPaint(
                painter: _SpotlightPainter(target: rect, pulse: _pulseController.value, accentColor: accentColor),
              ),
            ),
          ),
        ),
        _TutorialBubble(
          step: step,
          targetRect: rect,
          screenSize: screenSize,
          stepNumber: tutorial.stepIndex + 1,
          totalSteps: tutorialSteps.length,
          isLastStep: isLastStep,
          onNext: () => ref.read(tutorialProvider.notifier).next(),
          onSkip: () => ref.read(tutorialProvider.notifier).skip(),
        ),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect target;
  final double pulse; // 0.0 -> 1.0 -> 0.0
  final Color accentColor;

  _SpotlightPainter({required this.target, required this.pulse, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final holeRect = target.inflate(10);
    final holeRRect = RRect.fromRectAndRadius(holeRect, const Radius.circular(16));

    // Escurece tudo, exceto a área do alvo -- que fica exatamente como
    // está na tela, sem nenhum tratamento por cima (nem escurecer, nem
    // clarear artificialmente).
    final screenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(holeRRect);
    final scrimPath = Path.combine(PathOperation.difference, screenPath, holePath);
    canvas.drawPath(scrimPath, Paint()..color = Colors.black.withOpacity(0.8));

    // Brilho externo (glow) atrás da borda, pra reforçar o contorno mesmo
    // quando o conteúdo por trás já é escuro.
    final glowRRect = RRect.fromRectAndRadius(holeRect.inflate(2 + pulse * 4), const Radius.circular(18));
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
      oldDelegate.target != target || oldDelegate.pulse != pulse || oldDelegate.accentColor != accentColor;
}

class _TutorialBubble extends StatelessWidget {
  final TutorialStep step;
  final Rect targetRect;
  final Size screenSize;
  final int stepNumber;
  final int totalSteps;
  final bool isLastStep;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TutorialBubble({
    required this.step,
    required this.targetRect,
    required this.screenSize,
    required this.stepNumber,
    required this.totalSteps,
    required this.isLastStep,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    const margin = 16.0;
    const bubbleWidth = 320.0;
    final width = bubbleWidth > screenSize.width - margin * 2 ? screenSize.width - margin * 2 : bubbleWidth;

    final spaceBelow = screenSize.height - targetRect.bottom;
    final placeBelow = spaceBelow > 220 || targetRect.top < 220;

    double left = targetRect.center.dx - width / 2;
    if (left < margin) left = margin;
    if (left + width > screenSize.width - margin) left = screenSize.width - margin - width;

    return Positioned(
      left: left,
      child: placeBelow
          ? Padding(
              padding: EdgeInsets.only(top: targetRect.bottom + margin, left: 0),
              child: _bubbleCard(context, width),
            )
          : Padding(
              padding: EdgeInsets.only(bottom: screenSize.height - targetRect.top + margin, left: 0),
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
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$stepNumber DE $totalSteps',
              style: TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            Text(
              step.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              step.description,
              style: const TextStyle(fontSize: 14.5, height: 1.45, color: Colors.white, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  child: const Text('Pular', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                ElevatedButton.icon(
                  onPressed: onNext,
                  icon: Icon(isLastStep ? Icons.check_circle : Icons.arrow_forward, size: 18),
                  label: Text(
                    isLastStep ? 'Concluir' : step.nextLabel,
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
