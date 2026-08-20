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
}
