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
List<TutorialStep> tutorialStepsFor(String screen) {
  switch (screen) {
    case TutorialScreens.listas:
      return _listas;
    case TutorialScreens.listaDetalhe:
      return _listaDetalhe;
    case TutorialScreens.catalogo:
      return _catalogo;
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

final _catalogo = <TutorialStep>[
  const TutorialStep(
    title: 'Catálogo da família',
    description:
        'Todos os produtos que sua família já comprou ficam aqui, '
        'organizados por categoria -- compartilhados entre todos os '
        'membros da família.',
  ),
  const TutorialStep(
    title: 'Popular, Catálogo e Relatórios',
    description:
        '"Popular" mostra os itens mais comprados. "Catálogo" organiza '
        'tudo por categoria e tags (vegetariano, sem glúten...). '
        '"Relatórios" mostra quanto você gasta por categoria, produto e mês.',
  ),
  TutorialStep(
    title: 'Buscar um produto',
    description:
        'Digite aqui pra filtrar em qualquer uma das abas -- funciona pra '
        'produtos que você já tem no catálogo e ajuda a achar rápido antes '
        'de cadastrar um novo.',
    targetKey: TutorialKeys.catalogoSearchField,
  ),
  const TutorialStep(
    title: 'Adicionar à lista',
    description:
        'Toque no emoji do produto pra abrir e ajustar preço/quantidade '
        'antes de adicionar. Toque no + no canto pra adicionar direto, sem '
        'abrir nada -- rápido pra itens que você já sabe o preço.',
  ),
];
