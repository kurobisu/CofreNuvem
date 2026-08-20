import 'package:flutter/widgets.dart';

/// Um passo do tutorial: destaca um widget da tela e explica pra que serve.
///
/// [targetKey] aponta pro widget a destacar. Quando é null (ou o widget
/// ainda não está montado), o passo vira um cartão centralizado -- útil pra
/// introduções e telas vazias, onde o alvo ainda não existe.
class TutorialStep {
  const TutorialStep({
    required this.title,
    required this.description,
    this.targetKey,
  });

  final String title;
  final String description;
  final GlobalKey? targetKey;
}
