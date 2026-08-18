import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';

/// Uma lista de compras nomeada, com o progresso (itens marcados/total)
/// já calculado.
class ListaCompras {
  final String id;
  final String nome;
  final String status;
  final String? mercado;
  final int marcados;
  final int total;

  const ListaCompras({
    required this.id,
    required this.nome,
    required this.status,
    this.mercado,
    required this.marcados,
    required this.total,
  });

  double get progresso => total == 0 ? 0 : marcados / total;
}

Future<List<ListaCompras>> _fetchListas(String status) async {
  final supabase = SupabaseHelper.instance.client;

  // Tenta com 'mercado' primeiro; se a coluna ainda não existir no banco
  // (script scripts/add_marca_e_mercado.sql não rodado), cai pro select sem
  // ela em vez de quebrar a tela de listas inteira.
  List<dynamic> listasRaw;
  try {
    listasRaw = await supabase
        .from(SupabaseHelper.tableListasCompras)
        .select('id, nome, status, mercado, updated_at')
        .eq('status', status)
        .filter('deleted_at', 'is', null)
        .order('updated_at', ascending: false);
  } catch (_) {
    listasRaw = await supabase
        .from(SupabaseHelper.tableListasCompras)
        .select('id, nome, status, updated_at')
        .eq('status', status)
        .filter('deleted_at', 'is', null)
        .order('updated_at', ascending: false);
  }

  final itensRaw = await supabase
      .from(SupabaseHelper.tableListaCompras)
      .select('lista_id, comprado')
      .filter('deleted_at', 'is', null)
      .not('lista_id', 'is', null);

  final Map<String, int> totalPorLista = {};
  final Map<String, int> marcadosPorLista = {};
  for (final raw in itensRaw) {
    final item = CaseInsensitiveMap(raw as Map<String, dynamic>);
    final listaId = item['lista_id']?.toString();
    if (listaId == null) continue;
    totalPorLista[listaId] = (totalPorLista[listaId] ?? 0) + 1;
    final comprado = item['comprado'];
    if (comprado == 1 || comprado == true) {
      marcadosPorLista[listaId] = (marcadosPorLista[listaId] ?? 0) + 1;
    }
  }

  return listasRaw.map((raw) {
    final lista = CaseInsensitiveMap(raw as Map<String, dynamic>);
    final id = lista['id'].toString();
    final mercado = lista['mercado']?.toString().trim();
    return ListaCompras(
      id: id,
      nome: (lista['nome'] ?? '').toString(),
      status: (lista['status'] ?? 'Ativa').toString(),
      mercado: (mercado == null || mercado.isEmpty) ? null : mercado,
      marcados: marcadosPorLista[id] ?? 0,
      total: totalPorLista[id] ?? 0,
    );
  }).toList();
}

final listasAtivasProvider = FutureProvider<List<ListaCompras>>(
  (ref) => _fetchListas('Ativa'),
);
final listasConcluidasProvider = FutureProvider<List<ListaCompras>>(
  (ref) => _fetchListas('Concluida'),
);

/// Dados da própria lista (nome/mercado/status) -- usado pra mostrar e
/// editar o mercado dentro do ListaDetalheScreen sem precisar recarregar a
/// tela inteira de Listas.
final listaInfoProvider = FutureProvider.family<Map<String, dynamic>?, String>((
  ref,
  listaId,
) async {
  final supabase = SupabaseHelper.instance.client;
  final raw = await supabase
      .from(SupabaseHelper.tableListasCompras)
      .select()
      .eq('id', listaId)
      .maybeSingle();
  if (raw == null) return null;
  return CaseInsensitiveMap(raw);
});

/// Itens de uma lista especifica, ja separados por marcado/nao marcado.
final listaItensProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      listaId,
    ) async {
      final supabase = SupabaseHelper.instance.client;
      final raw = await supabase
          .from(SupabaseHelper.tableListaCompras)
          .select(
            '*, produtos_catalogo(nome, emoji, categoria_id, categorias_produtos(nome))',
          )
          .eq('lista_id', listaId)
          .filter('deleted_at', 'is', null)
          .order('updated_at', ascending: false);
      return raw
          .map((e) => CaseInsensitiveMap(e as Map<String, dynamic>))
          .cast<Map<String, dynamic>>()
          .toList();
    });

/// Preco mais recente de cada produto (por produto_id) em QUALQUER lista
/// diferente da informada -- usado pra comparar "subiu/desceu desde a
/// ultima compra" sem contar o proprio item atual como "anterior".
final precosAnterioresProvider =
    FutureProvider.family<
      Map<String, double>,
      ({List<String> produtoIds, String excetoListaId})
    >((ref, params) async {
      if (params.produtoIds.isEmpty) return {};
      final supabase = SupabaseHelper.instance.client;
      final raw = await supabase
          .from(SupabaseHelper.tableListaCompras)
          .select('produto_id, preco, updated_at')
          .inFilter('produto_id', params.produtoIds)
          .neq('lista_id', params.excetoListaId)
          .not('preco', 'is', null)
          .filter('deleted_at', 'is', null)
          .order('updated_at', ascending: false);

      final Map<String, double> result = {};
      for (final r in raw) {
        final row = CaseInsensitiveMap(r as Map<String, dynamic>);
        final produtoId = row['produto_id']?.toString();
        if (produtoId == null || result.containsKey(produtoId)) continue;
        result[produtoId] = ((row['preco'] ?? 0) as num).toDouble();
      }
      return result;
    });

class ListasComprasRepo {
  static final _client = SupabaseHelper.instance.client;

  static Future<String> criar(String nome) async {
    final res = await _client
        .from(SupabaseHelper.tableListasCompras)
        .insert({'nome': nome.trim()})
        .select('id')
        .single();
    return res['id'].toString();
  }

  static Future<void> renomear(String id, String novoNome) async {
    await _client
        .from(SupabaseHelper.tableListasCompras)
        .update({
          'nome': novoNome.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Define/limpa o mercado onde a lista foi/será comprada -- usado pra
  /// filtrar os Relatórios por origem. Falha em silêncio se a coluna ainda
  /// não existir (script scripts/add_marca_e_mercado.sql não rodado).
  static Future<void> definirMercado(String id, String? mercado) async {
    final valor = (mercado == null || mercado.trim().isEmpty)
        ? null
        : mercado.trim();
    try {
      await _client
          .from(SupabaseHelper.tableListasCompras)
          .update({'mercado': valor})
          .eq('id', id);
    } catch (_) {}
  }

  /// Remove um item específico de uma lista (soft delete) -- usado pelo
  /// swipe-to-delete. Funciona tanto pra itens ligados ao catálogo quanto
  /// pra itens avulsos (produto_id nulo), já que mira o id da própria linha.
  static Future<void> removerItem(String itemId) async {
    await _client
        .from(SupabaseHelper.tableListaCompras)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', itemId);
  }

  static Future<void> excluir(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from(SupabaseHelper.tableListaCompras)
        .update({'deleted_at': now})
        .eq('lista_id', id);
    await _client
        .from(SupabaseHelper.tableListasCompras)
        .update({'deleted_at': now})
        .eq('id', id);
  }

  static Future<String> duplicar(String id, String nome) async {
    final novaListaId = await criar(nome);
    final itens = await _client
        .from(SupabaseHelper.tableListaCompras)
        .select()
        .eq('lista_id', id)
        .filter('deleted_at', 'is', null);

    for (final raw in itens) {
      final item = CaseInsensitiveMap(raw as Map<String, dynamic>);
      await _client.from(SupabaseHelper.tableListaCompras).insert({
        'auth_id': _client.auth.currentUser?.id,
        'lista_id': novaListaId,
        'nome': item['nome'],
        'produto_id': item['produto_id'],
        'preco': item['preco'],
        'quantidade': item['quantidade'],
        'unidade': item['unidade'] ?? 'Unidade',
        'comprado': 0,
      });
    }
    return novaListaId;
  }

  /// Cria uma lista nova com os itens de uma lista antiga (do historico),
  /// todos desmarcados -- pra "repetir" uma compra anterior.
  static Future<String> copiarParaNovaLista(
    String listaOrigemId,
    String novoNome,
  ) => duplicar(listaOrigemId, novoNome);

  static Future<void> marcarTodos(String listaId, bool marcado) async {
    await _client
        .from(SupabaseHelper.tableListaCompras)
        .update({'comprado': marcado ? 1 : 0})
        .eq('lista_id', listaId)
        .filter('deleted_at', 'is', null);
  }

  static Future<void> concluirLista(String listaId) async {
    await _client
        .from(SupabaseHelper.tableListasCompras)
        .update({
          'status': 'Concluida',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', listaId);
  }
}
