import 'package:flutter/widgets.dart';

/// Um passo do tutorial: destaca um widget da tela e explica pra que serve.
///
/// [targetKey] aponta pro widget a destacar. Quando é null (ou o widget
/// ainda não está montado), o passo vira um cartão centralizado -- útil pra
/// introduções e telas vazias, onde o alvo ainda não existe.
///
/// [onEnter], quando informado, roda assim que o tutorial chega neste passo
/// -- usado por telas com abas (ex.: CatalogoScreen) pra trocar de aba
/// conforme o passo explica cada uma, em vez de ficar parado numa só
/// enquanto o texto fala de outra.
class TutorialStep {
  const TutorialStep({
    required this.title,
    required this.description,
    this.targetKey,
    this.onEnter,
  });

  final String title;
  final String description;
  final GlobalKey? targetKey;
  final VoidCallback? onEnter;
}
