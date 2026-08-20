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
  static const ajustes = 'ajustes';
  static const contas = 'ajustes_contas';
  static const categorias = 'ajustes_categorias';
  static const usuarios = 'ajustes_usuarios';
  static const familia = 'ajustes_familia';
  static const investimentos = 'investimentos';
  static const investimentoDetalhe = 'investimento_detalhe';
  static const dashboard = 'dashboard';
  static const transactionForm = 'transaction_form';
  static const reports = 'reports';
  static const familyTransfer = 'family_transfer';
  static const invoices = 'invoices';
  static const transactionHistory = 'transaction_history';
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
    case TutorialScreens.ajustes:
      return _ajustes;
    case TutorialScreens.contas:
      return _contas;
    case TutorialScreens.categorias:
      return _categorias;
    case TutorialScreens.usuarios:
      return _usuarios;
    case TutorialScreens.familia:
      return _familia;
    case TutorialScreens.investimentos:
      return _investimentos;
    case TutorialScreens.investimentoDetalhe:
      return _investimentoDetalhe;
    case TutorialScreens.dashboard:
      return _dashboard;
    case TutorialScreens.transactionForm:
      return _transactionForm;
    case TutorialScreens.reports:
      return _reports;
    case TutorialScreens.familyTransfer:
      return _familyTransfer;
    case TutorialScreens.invoices:
      return _invoices;
    case TutorialScreens.transactionHistory:
      return _transactionHistory;
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

final _ajustes = <TutorialStep>[
  const TutorialStep(
    title: 'Ajustes',
    description:
        'Aqui fica tudo que configura o app: categorias, contas e cartões, '
        'quem usa o app com você, compartilhamento familiar, backup e sua '
        'conta.',
  ),
  TutorialStep(
    title: 'Cadastros',
    description:
        'Categorias (pra organizar despesas e receitas), Contas & Métodos '
        '(bancos, carteira, cartões de crédito) e Usuários (quem são as '
        'pessoas que usam o app na sua família) -- cada um tem seu próprio '
        'tutorial quando você entra.',
    targetKey: TutorialKeys.settingsCadastrosCard,
  ),
  TutorialStep(
    title: 'Família & Compartilhamento',
    description:
        'Convide outras pessoas pra compartilhar a gestão financeira. Os '
        'dados de cada família ficam isolados -- só quem você convidar, e '
        'aceitar, tem acesso.',
    targetKey: TutorialKeys.settingsFamiliaCard,
  ),
  TutorialStep(
    title: 'Forçar Sincronização',
    description:
        'Se algo ficou "preso" na tela depois de uma edição feita em outro '
        'aparelho ou outra aba, toque aqui pra recarregar tudo direto da '
        'nuvem.',
    targetKey: TutorialKeys.settingsSincronizarTile,
  ),
  TutorialStep(
    title: 'Exportar para CSV',
    description:
        'Gera um arquivo com todas as suas transações, compatível com '
        'Excel/Planilhas Google -- útil pra backup ou análises fora do app.',
    targetKey: TutorialKeys.settingsExportarTile,
  ),
];

final _contas = <TutorialStep>[
  const TutorialStep(
    title: 'Contas & Métodos',
    description:
        'Cada conta (banco, carteira de dinheiro físico...) pode ter vários '
        'métodos de pagamento dentro dela -- PIX, Débito, Crédito. Toque numa '
        'conta pra abrir e ver os métodos dela.',
  ),
  TutorialStep(
    title: 'Nova conta',
    description:
        'Toque aqui pra adicionar um banco, carteira digital ou dinheiro '
        'físico. Contas com PIX/Débito já vêm com esses métodos prontos.',
    targetKey: TutorialKeys.contasAddButton,
  ),
  const TutorialStep(
    title: 'Cartão de crédito',
    description:
        'Ao adicionar um método "Crédito", informe o Dia de Fechamento '
        '(quando a fatura para de somar compras) e o Dia de Vencimento '
        '(quando você paga a fatura) -- isso é o que o app usa pra calcular '
        'em qual fatura cada compra parcelada cai.',
  ),
];

final _categorias = <TutorialStep>[
  const TutorialStep(
    title: 'Categorias',
    description:
        'Três abas: Receitas, Despesas e Mercado (usada pelas compras que '
        'você finaliza no módulo Compras). Segure e arraste pra reordenar; '
        'toque no interruptor pra ocultar uma categoria sem apagá-la.',
  ),
  TutorialStep(
    title: 'Nova categoria',
    description:
        'Toque aqui pra criar uma categoria própria -- ou o "+" ao lado de '
        'uma categoria já existente pra criar uma subcategoria dela.',
    targetKey: TutorialKeys.categoriasAddButton,
  ),
  const TutorialStep(
    title: 'Reordenar e salvar',
    description:
        'Arraste pra mudar a ordem -- um botão "SALVAR" aparece na barra de '
        'cima assim que houver uma mudança pendente. As mudanças de ordem só '
        'valem depois que você tocar nele.',
  ),
];

final _usuarios = <TutorialStep>[
  const TutorialStep(
    title: 'Usuários',
    description:
        'Diferente de quem faz login no app (sua conta de e-mail), '
        '"Usuário" aqui é o perfil que fica "dono" de cada despesa, receita '
        'e conta -- pra saber de quem é o quê dentro da família.',
  ),
  TutorialStep(
    title: 'Novo usuário',
    description:
        'Toque aqui pra adicionar mais um perfil. Ative "Usuário de Gestão" '
        'pra representar alguém que não faz login sozinho -- um filho, '
        'dependente, ou um cofre conjunto da família.',
    targetKey: TutorialKeys.usuariosAddButton,
  ),
];

final _familia = <TutorialStep>[
  const TutorialStep(
    title: 'Compartilhamento familiar',
    description:
        'Convide outras contas do CofreNuvem pra sua família -- as contas, '
        'transações e listas de compras de todo mundo ficam sincronizadas e '
        'visíveis entre si.',
  ),
  TutorialStep(
    title: 'Convidar por e-mail',
    description:
        'Digite o e-mail de quem você quer convidar. A pessoa precisa já '
        'ter uma conta no CofreNuvem, e só entra na família se aceitar o '
        'convite (que aparece pra ela nesta mesma tela).',
    targetKey: TutorialKeys.familiaConvidarCard,
  ),
];

final _investimentos = <TutorialStep>[
  const TutorialStep(
    title: 'Meus Investimentos',
    description:
        'Acompanhe seus ativos (CDB, ações, fundos...), veja quanto rendeu e '
        'defina metas financeiras -- tudo nesta tela.',
  ),
  TutorialStep(
    title: 'Novo investimento',
    description:
        'Toque aqui pra cadastrar um ativo novo, ou fazer um aporte extra '
        'num ativo que você já tem (ex: comprar mais cota do mesmo CDB).',
    targetKey: TutorialKeys.investimentosAddButton,
  ),
  TutorialStep(
    title: 'Patrimônio Atualizado',
    description:
        'O card mostra quanto você tem hoje, quanto investiu no total, e o '
        'rendimento líquido (a diferença entre os dois) -- em valor e em %.',
    targetKey: TutorialKeys.investimentosPatrimonioCard,
  ),
  TutorialStep(
    title: 'Alocação e evolução',
    description:
        'Alterne entre o gráfico de pizza (como seu dinheiro está dividido '
        'entre os ativos) e o de linha (como o total evoluiu ao longo do '
        'tempo, por dia, semana, mês ou ano).',
    targetKey: TutorialKeys.investimentosChartToggle,
  ),
  TutorialStep(
    title: 'Atualizar Rendimento',
    description:
        'O app não busca cotação sozinho -- toque aqui de vez em quando pra '
        'informar o valor atual de cada investimento e manter o rendimento '
        'em dia.',
    targetKey: TutorialKeys.investimentosAtualizarButton,
  ),
  TutorialStep(
    title: 'Metas Financeiras',
    description:
        'Crie uma meta (ex: dar entrada num carro) e acompanhe o progresso '
        'com base no seu patrimônio atual. Informe um aporte mensal '
        'planejado ou uma data alvo, e o app calcula o resto.',
    targetKey: TutorialKeys.investimentosMetaAddButton,
  ),
];

final _investimentoDetalhe = <TutorialStep>[
  const TutorialStep(
    title: 'Detalhes do investimento',
    description:
        'Aqui fica o histórico completo deste ativo: todos os aportes e '
        'resgates, e o gráfico de evolução do saldo ao longo do tempo.',
  ),
  TutorialStep(
    title: 'Resgatar',
    description:
        'Toque aqui pra retirar parte ou todo o valor investido -- o app '
        'lança uma Receita na conta de destino e recalcula automaticamente '
        'quanto ainda está investido. Resgatando tudo, o ativo é marcado '
        'como encerrado.',
    targetKey: TutorialKeys.investimentoDetalheResgatarButton,
  ),
];

final _dashboard = <TutorialStep>[
  const TutorialStep(
    title: 'Visão Geral',
    description:
        'A tela inicial do app: saldo da família, saldo de cada pessoa, '
        'cartões de crédito e as últimas transações -- tudo num só lugar.',
  ),
  TutorialStep(
    title: 'Saldo Familiar Total',
    description:
        'A soma de todas as contas de todos os membros da família -- o '
        'quanto vocês têm, juntos, agora.',
    targetKey: TutorialKeys.dashboardSaldoCard,
  ),
  TutorialStep(
    title: 'Saldo individual',
    description:
        'Toque no nome de alguém pra ver o extrato dela por conta e método '
        'de pagamento, com um botão de "Transferir" pra mandar dinheiro de '
        'uma conta pra outra dentro da família.',
    targetKey: TutorialKeys.dashboardUserBalancesList,
  ),
  TutorialStep(
    title: 'Cartões & Faturas',
    description:
        'Cada cartão de crédito mostra quanto do limite já foi usado. '
        'Toque num cartão pra ver as faturas, mês a mês, e marcar como paga.',
    targetKey: TutorialKeys.dashboardCartoesRow,
  ),
  TutorialStep(
    title: 'Últimas Transações',
    description:
        'Toque numa transação pra editar, excluir, ou ver o cupom fiscal '
        '(quando ela veio de uma lista de compras finalizada). "Ver tudo" '
        'abre o histórico completo, com busca e filtros.',
    targetKey: TutorialKeys.dashboardVerTudoButton,
  ),
  TutorialStep(
    title: 'Relatórios Avançados',
    description:
        'Gráficos de entrada e saída por categoria, banco e por pessoa da '
        'família, com filtro por mês.',
    targetKey: TutorialKeys.dashboardRelatoriosButton,
  ),
  TutorialStep(
    title: 'Lançar despesa ou receita',
    description:
        'O botão "+" cria uma transação nova -- despesa ou receita, à vista '
        'ou parcelada, paga ou pendente. É o mesmo formulário usado em '
        'qualquer lugar do app que lança uma transação.',
    targetKey: TutorialKeys.dashboardFab,
  ),
];

final _transactionForm = <TutorialStep>[
  const TutorialStep(
    title: 'Nova Transação',
    description:
        'Preencha valor, descrição, quem pagou/recebeu, categoria e a '
        'conta/método usados -- e toque em Salvar Lançamento.',
  ),
  TutorialStep(
    title: 'Despesa ou Receita',
    description:
        'Escolha se é dinheiro saindo (Despesa) ou entrando (Receita). Isso '
        'muda quais categorias aparecem na lista abaixo.',
    targetKey: TutorialKeys.transactionFormTipoSelector,
  ),
  TutorialStep(
    title: 'Transação Paga?',
    description:
        'Desmarque pra lançar algo que ainda vai acontecer (uma conta a '
        'pagar, um recebimento futuro). Transações pendentes aparecem com '
        'um aviso laranja até você marcá-las como pagas.',
    targetKey: TutorialKeys.transactionFormPagaSwitch,
  ),
  TutorialStep(
    title: 'Parcelamento',
    description:
        'Pra uma compra parcelada no cartão, ative "Parcelado" e escolha '
        'quantas parcelas. "Iniciando na" serve pra lançar uma compra que '
        'você já vinha pagando antes de usar o app -- pulando direto pra '
        'parcela em que você está agora, sem recriar as que já passaram.',
    targetKey: TutorialKeys.transactionFormParcelamento,
  ),
];

final _reports = <TutorialStep>[
  const TutorialStep(
    title: 'Relatórios Avançados',
    description:
        'Veja pra onde o dinheiro da família está indo: gasto por '
        'categoria, e entrada/saída por banco e por pessoa, tudo no mês '
        'selecionado.',
  ),
  TutorialStep(
    title: 'Trocar o mês',
    description:
        'Toque aqui pra ver o mesmo relatório em qualquer um dos últimos '
        '12 meses.',
    targetKey: TutorialKeys.reportsMonthSelector,
  ),
  const TutorialStep(
    title: 'Toque pra detalhar',
    description:
        'Toque numa fatia do gráfico ou numa barra pra ver o valor exato '
        'por baixo -- os gráficos aqui são todos interativos.',
  ),
];

final _familyTransfer = <TutorialStep>[
  const TutorialStep(
    title: 'Transferir entre familiares',
    description:
        'Move dinheiro de uma conta pra outra dentro da família -- o app '
        'lança uma Despesa na conta de origem e uma Receita na conta de '
        'destino, ligadas uma à outra.',
  ),
  TutorialStep(
    title: 'Inverter remetente/destinatário',
    description:
        'Toque na seta pra trocar quem envia e quem recebe, sem precisar '
        'refazer a tela do zero.',
    targetKey: TutorialKeys.familyTransferSwapButton,
  ),
  const TutorialStep(
    title: 'Desfazer uma transferência',
    description:
        'Se precisar reverter, abra a transação (na Visão Geral ou no '
        'Histórico) e toque em "Devolver Valor"/"Recuperar Valor" -- isso '
        'já pré-preenche uma transferência de volta, na direção contrária.',
  ),
];

final _invoices = <TutorialStep>[
  const TutorialStep(
    title: 'Faturas do cartão',
    description:
        'A barra no topo mostra quanto do limite já está comprometido em '
        'faturas ainda abertas. Cada fatura abaixo é agrupada pelo dia de '
        'vencimento.',
  ),
  const TutorialStep(
    title: 'Pagar uma fatura',
    description:
        'Toque numa fatura pra abrir e ver as compras dela. "Pagar Fatura '
        'Completa" marca todas as transações daquele mês como pagas de uma '
        'vez.',
  ),
];

final _transactionHistory = <TutorialStep>[
  const TutorialStep(
    title: 'Histórico completo',
    description:
        'Todas as transações da família, mais recentes primeiro. Toque numa '
        'pra editar, excluir ou ver o cupom fiscal.',
  ),
  TutorialStep(
    title: 'Buscar e filtrar',
    description:
        'Digite no campo de busca pra filtrar por nome, valor ou categoria. '
        'O ícone de filtro adiciona filtros por mês, categoria e outros '
        'critérios.',
    targetKey: TutorialKeys.historyFilterButton,
  ),
];

