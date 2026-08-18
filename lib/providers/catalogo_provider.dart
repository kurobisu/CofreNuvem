import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';

const tagsDisponiveis = ['Vegetariano', 'Vegano', 'Keto', 'Sem Glúten', 'Alto teor de proteína', 'Congelador'];

final categoriasProdutoProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = SupabaseHelper.instance.client;
  final raw = await supabase.from(SupabaseHelper.tableCategoriasProdutos).select().order('ordem', ascending: true);
  return raw.map((e) => CaseInsensitiveMap(e as Map<String, dynamic>)).cast<Map<String, dynamic>>().toList();
});

final produtosPorCategoriaProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, categoriaId) async {
  final supabase = SupabaseHelper.instance.client;
  final raw = await supabase
      .from(SupabaseHelper.tableProdutosCatalogo)
      .select()
      .eq('categoria_id', categoriaId)
      .filter('deleted_at', 'is', null)
      .order('nome', ascending: true);
  return raw.map((e) => CaseInsensitiveMap(e as Map<String, dynamic>)).cast<Map<String, dynamic>>().toList();
});

final produtosPorTagProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, tag) async {
  final supabase = SupabaseHelper.instance.client;
  final raw = await supabase
      .from(SupabaseHelper.tableProdutosCatalogo)
      .select()
      .contains('tags', [tag])
      .filter('deleted_at', 'is', null)
      .order('nome', ascending: true);
  return raw.map((e) => CaseInsensitiveMap(e as Map<String, dynamic>)).cast<Map<String, dynamic>>().toList();
});

final buscarProdutosProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final supabase = SupabaseHelper.instance.client;
  final raw = await supabase
      .from(SupabaseHelper.tableProdutosCatalogo)
      .select()
      .ilike('nome', '%${query.trim()}%')
      .filter('deleted_at', 'is', null)
      .order('nome', ascending: true)
      .limit(30);
  return raw.map((e) => CaseInsensitiveMap(e as Map<String, dynamic>)).cast<Map<String, dynamic>>().toList();
});

/// Produtos mais comprados pela familia (por frequencia de aparicao em
/// listas passadas), do mais pro menos frequente.
final produtosPopularesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
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

  final idsOrdenados = contagem.keys.toList()..sort((a, b) => contagem[b]!.compareTo(contagem[a]!));
  final top = idsOrdenados.take(24).toList();

  final produtosRaw = await supabase
      .from(SupabaseHelper.tableProdutosCatalogo)
      .select()
      .inFilter('id', top)
      .filter('deleted_at', 'is', null);

  final produtos = produtosRaw.map((e) => CaseInsensitiveMap(e as Map<String, dynamic>)).cast<Map<String, dynamic>>().toList();
  produtos.sort((a, b) {
    final ca = contagem[a['id'].toString()] ?? 0;
    final cb = contagem[b['id'].toString()] ?? 0;
    return cb.compareTo(ca);
  });
  return produtos;
});

class CatalogoRepo {
  static final _client = SupabaseHelper.instance.client;

  static Future<String> criarProdutoCustomizado({
    required String nome,
    required String categoriaId,
    required String emoji,
    required List<String> tags,
    String unidadePadrao = 'Unidade',
  }) async {
    final res = await _client.from(SupabaseHelper.tableProdutosCatalogo).insert({
      'auth_id': _client.auth.currentUser?.id,
      'nome': nome.trim(),
      'categoria_id': categoriaId,
      'emoji': emoji,
      'tags': tags,
      'unidade_padrao': unidadePadrao,
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

  static Future<void> removerDaLista({required String listaId, required String produtoId}) async {
    await _client
        .from(SupabaseHelper.tableListaCompras)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('lista_id', listaId)
        .eq('produto_id', produtoId);
  }
}
