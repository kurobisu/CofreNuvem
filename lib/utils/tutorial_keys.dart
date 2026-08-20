import 'package:flutter/material.dart';

/// GlobalKeys usados pelo tutorial de cada tela pra localizar e destacar
/// (spotlight) os widgets que ele explica. Ficam centralizados aqui porque
/// o conteúdo dos passos (lib/utils/tutorial_content.dart) referencia esses
/// widgets sem depender de onde a tela os declara.
class TutorialKeys {
  TutorialKeys._();

  // Compras -- lista de listas (ListasScreen)
  static final GlobalKey listasCatalogoButton =
      GlobalKey(debugLabel: 'tutorial_listas_catalogo_button');
  static final GlobalKey listasAddButton =
      GlobalKey(debugLabel: 'tutorial_listas_add_button');
  static final GlobalKey listasHistoricoButton =
      GlobalKey(debugLabel: 'tutorial_listas_historico_button');

  // Compras -- itens de uma lista (ListaDetalheScreen)
  static final GlobalKey listaDetalheMenuButton =
      GlobalKey(debugLabel: 'tutorial_lista_detalhe_menu_button');

  // Compras -- catálogo de produtos (CatalogoScreen)
  static final GlobalKey catalogoSearchField =
      GlobalKey(debugLabel: 'tutorial_catalogo_search_field');
  static final GlobalKey catalogoTabPopular =
      GlobalKey(debugLabel: 'tutorial_catalogo_tab_popular');
  static final GlobalKey catalogoTabCatalogo =
      GlobalKey(debugLabel: 'tutorial_catalogo_tab_catalogo');
  static final GlobalKey catalogoTabRelatorios =
      GlobalKey(debugLabel: 'tutorial_catalogo_tab_relatorios');

  // Ajustes -- tela principal (SettingsScreen)
  static final GlobalKey settingsCadastrosCard =
      GlobalKey(debugLabel: 'tutorial_settings_cadastros_card');
  static final GlobalKey settingsFamiliaCard =
      GlobalKey(debugLabel: 'tutorial_settings_familia_card');
  static final GlobalKey settingsSincronizarTile =
      GlobalKey(debugLabel: 'tutorial_settings_sincronizar_tile');
  static final GlobalKey settingsExportarTile =
      GlobalKey(debugLabel: 'tutorial_settings_exportar_tile');

  // Ajustes -- Contas & Métodos (ManageAccountsScreen)
  static final GlobalKey contasAddButton =
      GlobalKey(debugLabel: 'tutorial_contas_add_button');

  // Ajustes -- Categorias (ManageCategoriesScreen)
  static final GlobalKey categoriasAddButton =
      GlobalKey(debugLabel: 'tutorial_categorias_add_button');

  // Ajustes -- Usuários (ManageUsersScreen)
  static final GlobalKey usuariosAddButton =
      GlobalKey(debugLabel: 'tutorial_usuarios_add_button');

  // Ajustes -- Família & Compartilhamento (FamilyScreen)
  static final GlobalKey familiaConvidarCard =
      GlobalKey(debugLabel: 'tutorial_familia_convidar_card');

  // Investimentos -- tela principal (InvestmentsScreen)
  static final GlobalKey investimentosAddButton =
      GlobalKey(debugLabel: 'tutorial_investimentos_add_button');
  static final GlobalKey investimentosPatrimonioCard =
      GlobalKey(debugLabel: 'tutorial_investimentos_patrimonio_card');
  static final GlobalKey investimentosChartToggle =
      GlobalKey(debugLabel: 'tutorial_investimentos_chart_toggle');
  static final GlobalKey investimentosAtualizarButton =
      GlobalKey(debugLabel: 'tutorial_investimentos_atualizar_button');
  static final GlobalKey investimentosMetaAddButton =
      GlobalKey(debugLabel: 'tutorial_investimentos_meta_add_button');

  // Investimentos -- detalhe de um ativo (InvestmentDetailsScreen)
  static final GlobalKey investimentoDetalheResgatarButton =
      GlobalKey(debugLabel: 'tutorial_investimento_detalhe_resgatar_button');
}
