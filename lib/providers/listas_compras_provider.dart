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
  final double valorTotal;

  const ListaCompras({
    required this.id,
    required this.nome,
    required this.status,
    this.mercado,
    required this.marcados,
    required this.total,
    this.valorTotal = 0,
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
      .select('lista_id, comprado, preco, quantidade')
      .filter('deleted_at', 'is', null)
      .not('lista_id', 'is', null);

  final Map<String, int> totalPorLista = {};
  final Map<String, int> marcadosPorLista = {};
  final Map<String, double> valorPorLista = {};
  for (final raw in itensRaw) {
    final item = CaseInsensitiveMap(raw as Map<String, dynamic>);
    final listaId = item['lista_id']?.toString();
    if (listaId == null) continue;
    totalPorLista[listaId] = (totalPorLista[listaId] ?? 0) + 1;
    final comprado = item['comprado'];
    if (comprado == 1 || comprado == true) {
      marcadosPorLista[listaId] = (marcadosPorLista[listaId] ?? 0) + 1;
      final preco = ((item['preco'] ?? 0) as num).toDouble();
      final quantidade = ((item['quantidade'] ?? 1) as num).toDouble();
      valorPorLista[listaId] = (valorPorLista[listaId] ?? 0) + preco * quantidade;
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
      valorTotal: valorPorLista[id] ?? 0,
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
            '*, produtos_catalogo(nome, emoji, categoria_id, categorias_produtos(nome, emoji))',
          )
          .eq('lista_id', listaId)
          .filter('deleted_at', 'is', null)
          .order('updated_at', ascending: false);
      return raw
          .map((e) => CaseInsensitiveMap(e as Map<String, dynamic>))
          .cast<Map<String, dynamic>>()
          .toList();
    });

/// Preco mais recente de cada par (produto_id, marca_id) em QUALQUER lista
/// diferente da informada -- usado pra comparar "subiu/desceu desde a
/// ultima compra" sem contar o proprio item atual como "anterior". A chave
/// inclui a marca pra nao comparar o preco de marcas diferentes do mesmo
/// produto como se fossem a mesma coisa (ex: Cafe NesCafe vs Cafe Sao Braz).
///
/// [pares] recebe strings no formato 'produtoId::marcaId' (marcaId vazio
/// quando o item nao tem marca) -- ver [chaveProdutoMarca].
final precosAnterioresProvider =
    FutureProvider.family<
      Map<String, double>,
      ({List<String> pares, String excetoListaId})
    >((ref, params) async {
      if (params.pares.isEmpty) return {};
      final produtoIds = params.pares.map((p) => p.split('::').first).toSet().toList();
      final supabase = SupabaseHelper.instance.client;
      final raw = await supabase
          .from(SupabaseHelper.tableListaCompras)
          .select('produto_id, marca_id, preco, updated_at')
          .inFilter('produto_id', produtoIds)
          .neq('lista_id', params.excetoListaId)
          .not('preco', 'is', null)
          .filter('deleted_at', 'is', null)
          .order('updated_at', ascending: false);

      final Map<String, double> result = {};
      for (final r in raw) {
        final row = CaseInsensitiveMap(r as Map<String, dynamic>);
        final produtoId = row['produto_id']?.toString();
        if (produtoId == null) continue;
        final chave = chaveProdutoMarca(produtoId, row['marca_id']?.toString());
        if (result.containsKey(chave)) continue;
        result[chave] = ((row['preco'] ?? 0) as num).toDouble();
      }
      return result;
    });

/// Chave composta 'produtoId::marcaId' usada por [precosAnterioresProvider]
/// -- marcaId nulo/vazio vira '_' pra manter a chave estável.
String chaveProdutoMarca(String produtoId, String? marcaId) =>
    '$produtoId::${(marcaId == null || marcaId.isEmpty) ? '_' : marcaId}';

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

  /// Nomes de mercado já usados em listas anteriores desta família --
  /// alimenta o autocomplete de "Definir mercado" em ListaDetalheScreen, pra
  /// não deixar duas grafias diferentes do mesmo mercado (ex: "Atacadão" e
  /// "atacadao") virarem entradas separadas nos Relatórios.
  static Future<List<String>> mercadosConhecidos() async {
    try {
      final raw = await _client
          .from(SupabaseHelper.tableListasCompras)
          .select('mercado')
          .not('mercado', 'is', null)
          .filter('deleted_at', 'is', null);
      final nomes = raw
          .map((r) => (r['mercado'] ?? '').toString().trim())
          .where((m) => m.isNotEmpty)
          .toSet()
          .toList();
      nomes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return nomes;
    } catch (_) {
      return [];
    }
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
      final payload = <String, dynamic>{
        'auth_id': _client.auth.currentUser?.id,
        'lista_id': novaListaId,
        'nome': item['nome'],
        'produto_id': item['produto_id'],
        'marca_id': item['marca_id'],
        'preco': item['preco'],
        'quantidade': item['quantidade'],
        'unidade': item['unidade'] ?? 'Unidade',
        'comprado': 0,
      };
      try {
        await _client.from(SupabaseHelper.tableListaCompras).insert(payload);
      } catch (_) {
        // Coluna marca_id pode ainda nao existir (script
        // scripts/add_produto_marcas.sql nao rodado) -- copia o item mesmo
        // assim, so sem a marca.
        payload.remove('marca_id');
        await _client.from(SupabaseHelper.tableListaCompras).insert(payload);
      }
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

  static Future<void> concluirLista(String listaId, {String? transacaoId}) async {
    final payload = <String, dynamic>{
      'status': 'Concluida',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (transacaoId != null) payload['transacao_id'] = transacaoId;
    try {
      await _client
          .from(SupabaseHelper.tableListasCompras)
          .update(payload)
          .eq('id', listaId);
    } catch (_) {
      // Coluna transacao_id pode ainda nao existir (script
      // scripts/add_listas_compras_transacao_id.sql nao rodado) -- conclui
      // a lista mesmo assim, so sem o vinculo com a transacao.
      payload.remove('transacao_id');
      await _client
          .from(SupabaseHelper.tableListasCompras)
          .update(payload)
          .eq('id', listaId);
    }
  }

  /// Recalcula o valor da transacao vinculada a esta lista a partir dos
  /// itens 'comprado' atuais -- chamado depois de qualquer edicao numa
  /// lista ja concluida, pra manter a Transacao do Historico Financeiro
  /// sincronizada com o que a lista realmente tem marcado.
  ///
  /// No-op se: a lista nao tem transacao vinculada (nao foi concluida pelo
  /// fluxo normal, ou o script da coluna ainda nao rodou); a transacao faz
  /// parte de uma compra parcelada (nao da pra redistribuir o novo total
  /// entre parcelas com seguranca); ou o novo total ficaria zero (uma
  /// transacao financeira nao devia virar R$0 silenciosamente).
  static Future<void> sincronizarTransacaoDaLista(String listaId) async {
    try {
      final lista = await _client
          .from(SupabaseHelper.tableListasCompras)
          .select('transacao_id')
          .eq('id', listaId)
          .maybeSingle();
      final transacaoId = lista?['transacao_id']?.toString();
      if (transacaoId == null) return;

      final transacao = await _client
          .from(SupabaseHelper.tableTransacoes)
          .select('parcela_total')
          .eq('id', transacaoId)
          .maybeSingle();
      final parcelaTotal =
          (transacao?['parcela_total'] as num?)?.toInt() ?? 1;
      if (parcelaTotal > 1) return;

      final itensRaw = await _client
          .from(SupabaseHelper.tableListaCompras)
          .select('preco, quantidade')
          .eq('lista_id', listaId)
          .eq('comprado', 1)
          .filter('deleted_at', 'is', null);
      double total = 0;
      for (final raw in itensRaw) {
        final item = CaseInsensitiveMap(raw as Map<String, dynamic>);
        total += ((item['preco'] as num?)?.toDouble() ?? 0) *
            ((item['quantidade'] as num?)?.toDouble() ?? 1);
      }
      if (total <= 0) return;

      await _client
          .from(SupabaseHelper.tableTransacoes)
          .update({
            'valor': total,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', transacaoId);
    } catch (_) {}
  }

  /// Exclui uma lista ja concluida. Se [excluirTransacaoVinculada], tambem
  /// exclui (soft delete) a transacao financeira que essa lista gerou ao
  /// ser finalizada -- inclusive o grupo inteiro de parcelas, se for o
  /// caso, pra nao sobrar parcela orfa no Historico Financeiro.
  static Future<void> excluirConcluida(
    String id, {
    required bool excluirTransacaoVinculada,
  }) async {
    if (excluirTransacaoVinculada) {
      try {
        final lista = await _client
            .from(SupabaseHelper.tableListasCompras)
            .select('transacao_id')
            .eq('id', id)
            .maybeSingle();
        final transacaoId = lista?['transacao_id']?.toString();
        if (transacaoId != null) {
          final now = DateTime.now().toUtc().toIso8601String();
          final transacao = await _client
              .from(SupabaseHelper.tableTransacoes)
              .select('grupo_parcela_id')
              .eq('id', transacaoId)
              .maybeSingle();
          final grupoId = transacao?['grupo_parcela_id']?.toString();
          if (grupoId != null && grupoId.isNotEmpty) {
            await _client
                .from(SupabaseHelper.tableTransacoes)
                .update({'deleted_at': now})
                .eq('grupo_parcela_id', grupoId);
          } else {
            await _client
                .from(SupabaseHelper.tableTransacoes)
                .update({'deleted_at': now})
                .eq('id', transacaoId);
          }
        }
      } catch (_) {}
    }
    await excluir(id);
  }

  /// Busca o id e o valor atual da transacao vinculada a uma lista
  /// concluida (se houver) -- usado pra mostrar o valor real na 3a etapa de
  /// confirmacao de exclusao, em vez do total da propria lista (que pode
  /// ter ficado desatualizado se a sincronizacao falhou por algum motivo).
  /// Retorna null se a lista nao tem transacao vinculada, ou se a coluna
  /// listas_compras.transacao_id ainda nao existe (script
  /// scripts/add_listas_compras_transacao_id.sql nao rodado).
  static Future<double?> valorTransacaoVinculada(String listaId) async {
    try {
      final lista = await _client
          .from(SupabaseHelper.tableListasCompras)
          .select('transacao_id')
          .eq('id', listaId)
          .maybeSingle();
      final transacaoId = lista?['transacao_id']?.toString();
      if (transacaoId == null) return null;
      final transacao = await _client
          .from(SupabaseHelper.tableTransacoes)
          .select('valor')
          .eq('id', transacaoId)
          .maybeSingle();
      final valor = transacao?['valor'];
      return valor == null ? null : (valor as num).toDouble();
    } catch (_) {
      return null;
    }
  }
}
