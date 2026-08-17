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

class _TutorialOverlayState extends ConsumerState<TutorialOverlay> {
  Rect? _targetRect;
  int? _measuredForStep;
  bool _measuring = false;

  Future<void> _measure(int stepIndex) async {
    if (_measuring) return;
    _measuring = true;

    RenderBox? box;
    for (int i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) {
        _measuring = false;
        return;
      }
      final ctx = tutorialSteps[stepIndex].targetKey.currentContext;
      final rb = ctx?.findRenderObject();
      if (rb is RenderBox && rb.attached && rb.hasSize) {
        box = rb;
        break;
      }
    }

    if (!mounted) {
      _measuring = false;
      return;
    }
    _measuring = false;
    if (box == null) return; // alvo ainda não montado nessa passada; tenta de novo no próximo build

    final topLeft = box.localToGlobal(Offset.zero);
    setState(() {
      _targetRect = topLeft & box!.size;
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

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // absorve toques fora do fluxo do tour
            child: CustomPaint(painter: _SpotlightPainter(rect)),
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
  _SpotlightPainter(this.target);

  @override
  void paint(Canvas canvas, Size size) {
    final holeRect = target.inflate(8);
    final holeRRect = RRect.fromRectAndRadius(holeRect, const Radius.circular(14));

    final screenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(holeRRect);
    final scrimPath = Path.combine(PathOperation.difference, screenPath, holePath);

    canvas.drawPath(scrimPath, Paint()..color = Colors.black.withOpacity(0.75));
    canvas.drawRRect(
      holeRRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) => oldDelegate.target != target;
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
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$stepNumber de $totalSteps',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(step.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 8),
            Text(step.description, style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: onSkip, child: const Text('Pular')),
                ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(isLastStep ? 'Concluir' : step.nextLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
