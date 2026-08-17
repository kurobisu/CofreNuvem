import 'package:flutter/material.dart';

/// GlobalKeys usados pelo tour guiado para localizar e destacar (spotlight)
/// widgets espalhados por telas diferentes. Ficam centralizados aqui porque
/// o controlador do tour (lib/providers/tutorial_provider.dart) precisa
/// referenciá-los sem depender de cada tela individualmente.
class TutorialKeys {
  TutorialKeys._();

  static final GlobalKey settingsContas = GlobalKey(debugLabel: 'tutorial_settings_contas');
  static final GlobalKey settingsCategorias = GlobalKey(debugLabel: 'tutorial_settings_categorias');
  static final GlobalKey settingsFamilia = GlobalKey(debugLabel: 'tutorial_settings_familia');

  static final GlobalKey accountsAddFab = GlobalKey(debugLabel: 'tutorial_accounts_add_fab');
  static final GlobalKey categoriesAddFab = GlobalKey(debugLabel: 'tutorial_categories_add_fab');
  static final GlobalKey familyInviteCard = GlobalKey(debugLabel: 'tutorial_family_invite_card');

  static final GlobalKey dashboardFab = GlobalKey(debugLabel: 'tutorial_dashboard_fab');

  static final GlobalKey shoppingAddFab = GlobalKey(debugLabel: 'tutorial_shopping_add_fab');
  static final GlobalKey shoppingHistoryButton = GlobalKey(debugLabel: 'tutorial_shopping_history_button');
}
