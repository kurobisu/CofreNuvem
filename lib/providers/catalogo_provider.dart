import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';

const tagsDisponiveis = [
  'Vegetariano',
  'Vegano',
  'Keto',
  'Sem Glúten',
  'Alto teor de proteína',
  'Congelador',
];

const emojisDisponiveis = [
  '🛒',
  '🍎',
  '🥦',
  '🍞',
  '🧀',
  '🥩',
  '🐟',
  '🥫',
  '🥤',
  '☕',
  '🍷',
  '🧴',
  '🧸',
  '💊',
  '👕',
  '💐',
  '🧽',
  '📝',
  '🦴',
  '🍕',
  '🍪',
  '🥛',
  '🥚',
  '🍚',
];

final categoriasProdutoProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = SupabaseHelper.instance.client;
  final raw = await supabase
      .from(SupabaseHelper.tableCategoriasProdutos)
      .select()
      .order('ordem', ascending: true);
  return raw
      .map((e) => CaseInsensitiveMap(e as Map<String, dynamic>))
      .cast<Map<String, dynamic>>()
      .toList();
});

final produtosPorCategoriaProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      categoriaId,
    ) async {
      final supabase = SupabaseHelper.instance.client;
      final raw = await supabase
          .from(SupabaseHelper.tableProdutosCatalogo)
          .select()
          .eq('categoria_id', categoriaId)
          .filter('deleted_at', 'is', null)
          .order('nome', ascending: true);
      return raw
          .map((e) => CaseInsensitiveMap(e as Map<String, dynamic>))
          .cast<Map<String, dynamic>>()
          .toList();
    });

final produtosPorTagProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, tag) async {
      final supabase = SupabaseHelper.instance.client;
      final raw = await supabase
          .from(SupabaseHelper.tableProdutosCatalogo)
          .select()
          .contains('tags', [tag])
          .filter('deleted_at', 'is', null)
          .order('nome', ascending: true);
      return raw
          .map((e) => CaseInsensitiveMap(e as Map<String, dynamic>))
          .cast<Map<String, dynamic>>()
          .toList();
    });

final buscarProdutosProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      query,
    ) async {
      if (query.trim().isEmpty) return [];
      final supabase = SupabaseHelper.instance.client;
      final raw = await supabase
          .from(SupabaseHelper.tableProdutosCatalogo)
          .select()
          .ilike('nome', '%${query.trim()}%')
          .filter('deleted_at', 'is', null)
          .order('nome', ascending: true)
          .limit(30);
      return raw
          .map((e) => CaseInsensitiveMap(e as Map<String, dynamic>))
          .cast<Map<String, dynamic>>()
          .toList();
    });

/// Produtos mais comprados pela familia (por frequencia de aparicao em
/// listas passadas), do mais pro menos frequente.
final produtosPopularesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = SupabaseHelper.instance.client;

  final comprasRaw = await supabase
      .from(SupabaseHelper.tableListaCompras)
      .select('produto_id')
      .not('produto_id', 'is', null)
      .filter('deleted_at', 'is', null);

  final Map<String, int> contagem = {};
  for (final r in comprasRaw) {
    final row = CaseInsensitiveMap(r as Map<String, dynamic>);
    final produtoId = row['produto_id']?.toString();
    if (produtoId == null) continue;
    contagem[produtoId] = (contagem[produtoId] ?? 0) + 1;
  }

  if (contagem.isEmpty) return [];

  final idsOrdenados = contagem.keys.toList()
    ..sort((a, b) => contagem[b]!.compareTo(contagem[a]!));
  final top = idsOrdenados.take(15).toList();

  final produtosRaw = await supabase
      .from(SupabaseHelper.tableProdutosCatalogo)
      .select()
      .inFilter('id', top)
      .filter('deleted_at', 'is', null);

  final produtos = produtosRaw
      .map((e) => CaseInsensitiveMap(e as Map<String, dynamic>))
      .cast<Map<String, dynamic>>()
      .toList();
  produtos.sort((a, b) {
    final ca = contagem[a['id'].toString()] ?? 0;
    final cb = contagem[b['id'].toString()] ?? 0;
    return cb.compareTo(ca);
  });
  return produtos;
});

class CatalogoRepo {
  static final _client = SupabaseHelper.instance.client;

  /// Id da categoria "coringa" pra produtos criados sem categoria escolhida
  /// (categoria_id é NOT NULL no banco). Retorna null se o script
  /// scripts/add_sem_categoria.sql ainda não foi rodado no Supabase.
  static Future<String?> categoriaSemCategoriaId() async {
    try {
      final row = await _client
          .from(SupabaseHelper.tableCategoriasProdutos)
          .select('id')
          .eq('nome', 'Sem categoria')
          .maybeSingle();
      return row?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  static Future<String> criarProdutoCustomizado({
    required String nome,
    required String categoriaId,
    required String emoji,
    required List<String> tags,
    String unidadePadrao = 'Unidade',
  }) async {
    final payload = <String, dynamic>{
      'auth_id': _client.auth.currentUser?.id,
      'nome': nome.trim(),
      'categoria_id': categoriaId,
      'emoji': emoji,
      'tags': tags,
      'unidade_padrao': unidadePadrao,
    };
    final res = await _client
        .from(SupabaseHelper.tableProdutosCatalogo)
        .insert(payload)
        .select('id')
        .single();
    return res['id'].toString();
  }

  /// Marcas (variantes) de um produto do catálogo -- ex: o produto "Café"
  /// pode ter as marcas "NesCafé" e "São Braz", cada uma com seu próprio
  /// histórico de preço em lista_compras (via marca_id). Retorna lista
  /// vazia se o script scripts/add_produto_marcas.sql ainda não rodou.
  static Future<List<Map<String, dynamic>>> marcasDoProduto(
    String produtoId,
  ) async {
    try {
      final raw = await _client
          .from(SupabaseHelper.tableProdutoMarcas)
          .select()
          .eq('produto_id', produtoId)
          .filter('deleted_at', 'is', null)
          .order('nome', ascending: true);
      return raw
          .map((e) => CaseInsensitiveMap(e as Map<String, dynamic>))
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String> criarMarca(String produtoId, String nome) async {
    final res = await _client.from(SupabaseHelper.tableProdutoMarcas).insert({
      'auth_id': _client.auth.currentUser?.id,
      'produto_id': produtoId,
      'nome': nome.trim(),
    }).select('id').single();
    return res['id'].toString();
  }

  /// Adiciona um produto do catalogo como item numa lista de compras.
  static Future<void> adicionarNaLista({
    required String listaId,
    required Map<String, dynamic> produto,
    double quantidade = 1,
  }) async {
    await _client.from(SupabaseHelper.tableListaCompras).insert({
      'auth_id': _client.auth.currentUser?.id,
      'lista_id': listaId,
      'produto_id': produto['id'],
      'nome': produto['nome'],
      'unidade': produto['unidade_padrao'] ?? 'Unidade',
      'quantidade': quantidade,
      'comprado': 0,
    });
  }

  /// Atualiza ícone/tags de um produto já existente no catálogo -- usado
  /// pelo "Editar Item" quando aberto a partir do Catálogo.
  static Future<void> atualizarProduto({
    required String produtoId,
    required String emoji,
    required List<String> tags,
  }) async {
    await _client
        .from(SupabaseHelper.tableProdutosCatalogo)
        .update({'emoji': emoji, 'tags': tags})
        .eq('id', produtoId);
  }

  /// Remove um produto do catálogo (soft delete) -- itens que já existem em
  /// listas mantêm seu próprio nome/preço, só deixam de ser sugeridos.
  static Future<void> excluirProduto(String produtoId) async {
    await _client
        .from(SupabaseHelper.tableProdutosCatalogo)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', produtoId);
  }

  static Future<void> removerDaLista({
    required String listaId,
    required String produtoId,
  }) async {
    await _client
        .from(SupabaseHelper.tableListaCompras)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('lista_id', listaId)
        .eq('produto_id', produtoId);
  }
}
