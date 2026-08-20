import 'tutorial_keys.dart';
import 'tutorial_step.dart';

/// Identificadores das telas com tutorial (também usados como chave do "já
/// viu" no shared_preferences -- ver `TutorialSeenRepository` em
/// lib/providers/tutorial_provider.dart).
class TutorialScreens {
  TutorialScreens._();
  static const listas = 'compras_listas';
  static const listaDetalhe = 'compras_lista_detalhe';
  static const catalogo = 'compras_catalogo';
}

/// Passos por tela. Cada tutorial explica **só a tela em que o usuário
/// está** -- nada de tour que troca de tela sozinho.
///
/// [TutorialScreens.catalogo] não tem entrada aqui: seus passos trocam de
/// aba conforme avançam (ver [TutorialStep.onEnter]), o que exige o
/// `TabController` da própria tela -- CatalogoScreen monta os passos na
/// hora e passa via `TutorialButton.stepsBuilder` em vez de usar esta lista
/// estática.
List<TutorialStep> tutorialStepsFor(String screen) {
  switch (screen) {
    case TutorialScreens.listas:
      return _listas;
    case TutorialScreens.listaDetalhe:
      return _listaDetalhe;
    default:
      return const [];
  }
}

final _listas = <TutorialStep>[
  const TutorialStep(
    title: 'Suas listas de compras',
    description:
        'Crie quantas listas quiser -- mercado, farmácia, feira. Cada uma '
        'guarda seus próprios itens, preços e o mercado onde foi feita.',
  ),
  TutorialStep(
    title: 'Catálogo de produtos',
    description:
        'Aqui fica o catálogo compartilhado com sua família: produtos, '
        'marcas e o histórico de preço de cada um. Dá pra navegar nele '
        'mesmo sem nenhuma lista aberta.',
    targetKey: TutorialKeys.listasCatalogoButton,
  ),
  TutorialStep(
    title: 'Criar uma lista',
    description:
        'Toque aqui pra começar uma lista nova. Depois é só ir adicionando '
        'os itens que você precisa comprar.',
    targetKey: TutorialKeys.listasAddButton,
  ),
  TutorialStep(
    title: 'Listas concluídas',
    description:
        'Depois de finalizar uma compra, a lista fica guardada aqui, com o '
        'total gasto. Dá pra copiar os itens dela pra começar uma lista '
        'nova rapidinho.',
    targetKey: TutorialKeys.listasHistoricoButton,
  ),
];

final _listaDetalhe = <TutorialStep>[
  const TutorialStep(
    title: 'Adicionando itens',
    description:
        'Toque em "Eu preciso de..." lá embaixo pra adicionar um item. '
        'Digite o nome e o app sugere produtos do catálogo -- com preço, '
        'marca e histórico de compras anteriores.',
  ),
  const TutorialStep(
    title: 'Marcar como comprado',
    description:
        'Toque no círculo ao lado do item pra marcar que já foi pro '
        'carrinho. Os itens marcados descem pra uma seção separada, com o '
        'total do que já foi comprado até agora.',
  ),
  TutorialStep(
    title: 'Mais opções',
    description:
        'Aqui você renomeia a lista, define o mercado, ordena os itens, '
        'marca/desmarca todos de uma vez e finaliza a compra -- que cria '
        'uma transação com o valor total dos itens marcados.',
    targetKey: TutorialKeys.listaDetalheMenuButton,
  ),
];

