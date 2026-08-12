import '../database/supabase_helper.dart';

class DefaultData {
  static Future<void> seedDefaultCategories() async {
    final db = await SupabaseHelper.instance.database;
    final countRes = await db.rawQuery('SELECT COUNT(*) as c FROM ${SupabaseHelper.tableCategorias} WHERE deleted_at IS NULL');
    final count = countRes.first['c'] as int;

    // A nossa lista padrão tem cerca de 45 itens. Se tiver menos que isso,
    // significa que não injetamos ainda (são apenas sobras/bagunças de testes antigos).
    if (count >= 40) return;

    // Desvincula para não apagar transações por CASCADE
    await db.rawQuery('UPDATE ${SupabaseHelper.tableTransacoes} SET categoria_id = NULL');
    await db.rawQuery('UPDATE ${SupabaseHelper.tableProdutos} SET categoria_id = NULL');
    // Limpa a bagunça antiga
    await db.rawQuery('DELETE FROM ${SupabaseHelper.tableCategorias}');

    // --- ENTRADAS (Receitas) ---
    // Renda Principal
    String rendaPrincipalId = await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': 'Renda Principal', 'Cor_Hexadecimal': '#4CAF50', 'Tipo': 'Receita', 'Oculta': 0, 'Ordem': 0
    });
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Pró-labore / Salário', 'Cor_Hexadecimal': '#4CAF50', 'Tipo': 'Receita', 'Parent_ID': rendaPrincipalId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Distribuição de Lucros', 'Cor_Hexadecimal': '#4CAF50', 'Tipo': 'Receita', 'Parent_ID': rendaPrincipalId});

    // Renda Extra
    String rendaExtraId = await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': 'Renda Extra', 'Cor_Hexadecimal': '#8BC34A', 'Tipo': 'Receita', 'Oculta': 0, 'Ordem': 1
    });
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Serviços / Freelances', 'Cor_Hexadecimal': '#8BC34A', 'Tipo': 'Receita', 'Parent_ID': rendaExtraId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Vendas', 'Cor_Hexadecimal': '#8BC34A', 'Tipo': 'Receita', 'Parent_ID': rendaExtraId});

    // Rendimentos Financeiros
    String rendimentosId = await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': 'Rendimentos Financeiros', 'Cor_Hexadecimal': '#009688', 'Tipo': 'Receita', 'Oculta': 0, 'Ordem': 2
    });
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Resgates e Juros', 'Cor_Hexadecimal': '#009688', 'Tipo': 'Receita', 'Parent_ID': rendimentosId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Rendimentos de Conta (CDI)', 'Cor_Hexadecimal': '#009688', 'Tipo': 'Receita', 'Parent_ID': rendimentosId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Dividendos', 'Cor_Hexadecimal': '#009688', 'Tipo': 'Receita', 'Parent_ID': rendimentosId});

    // Outras Entradas
    String outrasId = await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': 'Outras Entradas', 'Cor_Hexadecimal': '#CDDC39', 'Tipo': 'Receita', 'Oculta': 0, 'Ordem': 3
    });
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Restituição de Impostos', 'Cor_Hexadecimal': '#CDDC39', 'Tipo': 'Receita', 'Parent_ID': outrasId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Cashback / Milhas', 'Cor_Hexadecimal': '#CDDC39', 'Tipo': 'Receita', 'Parent_ID': outrasId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Presentes (em dinheiro)', 'Cor_Hexadecimal': '#CDDC39', 'Tipo': 'Receita', 'Parent_ID': outrasId});

    // --- SAÍDAS (Despesas Gerais) ---
    String habitacaoId = await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': 'Habitação', 'Cor_Hexadecimal': '#2196F3', 'Tipo': 'Despesa', 'Oculta': 0, 'Ordem': 0
    });
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Parcela da Casa / Aluguel', 'Cor_Hexadecimal': '#2196F3', 'Tipo': 'Despesa', 'Parent_ID': habitacaoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Energia Elétrica', 'Cor_Hexadecimal': '#2196F3', 'Tipo': 'Despesa', 'Parent_ID': habitacaoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Água e Saneamento', 'Cor_Hexadecimal': '#2196F3', 'Tipo': 'Despesa', 'Parent_ID': habitacaoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Internet', 'Cor_Hexadecimal': '#2196F3', 'Tipo': 'Despesa', 'Parent_ID': habitacaoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Manut. Casa', 'Cor_Hexadecimal': '#2196F3', 'Tipo': 'Despesa', 'Parent_ID': habitacaoId});

    String transporteId = await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': 'Transporte', 'Cor_Hexadecimal': '#FF9800', 'Tipo': 'Despesa', 'Oculta': 0, 'Ordem': 1
    });
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Manut. Carro', 'Cor_Hexadecimal': '#FF9800', 'Tipo': 'Despesa', 'Parent_ID': transporteId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Combustível / Recarga', 'Cor_Hexadecimal': '#FF9800', 'Tipo': 'Despesa', 'Parent_ID': transporteId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Impostos e Seguro', 'Cor_Hexadecimal': '#FF9800', 'Tipo': 'Despesa', 'Parent_ID': transporteId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Aplicativos e Estacionamento', 'Cor_Hexadecimal': '#FF9800', 'Tipo': 'Despesa', 'Parent_ID': transporteId});

    String impostosId = await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': 'Impostos e Burocracias', 'Cor_Hexadecimal': '#607D8B', 'Tipo': 'Despesa', 'Oculta': 0, 'Ordem': 2
    });
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Simples Nacional / MEI', 'Cor_Hexadecimal': '#607D8B', 'Tipo': 'Despesa', 'Parent_ID': impostosId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Imposto de Renda', 'Cor_Hexadecimal': '#607D8B', 'Tipo': 'Despesa', 'Parent_ID': impostosId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Taxas Bancárias', 'Cor_Hexadecimal': '#607D8B', 'Tipo': 'Despesa', 'Parent_ID': impostosId});

    String saudeId = await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': 'Saúde e Bem-estar', 'Cor_Hexadecimal': '#00BCD4', 'Tipo': 'Despesa', 'Oculta': 0, 'Ordem': 3
    });
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Farmácia', 'Cor_Hexadecimal': '#00BCD4', 'Tipo': 'Despesa', 'Parent_ID': saudeId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Consultas e Exames', 'Cor_Hexadecimal': '#00BCD4', 'Tipo': 'Despesa', 'Parent_ID': saudeId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Plano de Saúde / Odonto', 'Cor_Hexadecimal': '#00BCD4', 'Tipo': 'Despesa', 'Parent_ID': saudeId});

    String educacaoId = await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': 'Educação e Desenv.', 'Cor_Hexadecimal': '#3F51B5', 'Tipo': 'Despesa', 'Oculta': 0, 'Ordem': 4
    });
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Cursos e Treinamentos', 'Cor_Hexadecimal': '#3F51B5', 'Tipo': 'Despesa', 'Parent_ID': educacaoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Livros e Materiais', 'Cor_Hexadecimal': '#3F51B5', 'Tipo': 'Despesa', 'Parent_ID': educacaoId});

    String lazerId = await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': 'Estilo de Vida e Lazer', 'Cor_Hexadecimal': '#9C27B0', 'Tipo': 'Despesa', 'Oculta': 0, 'Ordem': 5
    });
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Bares e Restaurantes', 'Cor_Hexadecimal': '#9C27B0', 'Tipo': 'Despesa', 'Parent_ID': lazerId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Software e Jogos', 'Cor_Hexadecimal': '#9C27B0', 'Tipo': 'Despesa', 'Parent_ID': lazerId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Assinaturas (Streaming)', 'Cor_Hexadecimal': '#9C27B0', 'Tipo': 'Despesa', 'Parent_ID': lazerId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Passeios e Viagens', 'Cor_Hexadecimal': '#9C27B0', 'Tipo': 'Despesa', 'Parent_ID': lazerId});

    String variaveisId = await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': 'Variáveis e Pessoais', 'Cor_Hexadecimal': '#FFC107', 'Tipo': 'Despesa', 'Oculta': 0, 'Ordem': 6
    });
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Vestimenta', 'Cor_Hexadecimal': '#FFC107', 'Tipo': 'Despesa', 'Parent_ID': variaveisId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Presentes', 'Cor_Hexadecimal': '#FFC107', 'Tipo': 'Despesa', 'Parent_ID': variaveisId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Eletrônicos', 'Cor_Hexadecimal': '#FFC107', 'Tipo': 'Despesa', 'Parent_ID': variaveisId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Compras Impulsivas', 'Cor_Hexadecimal': '#FFC107', 'Tipo': 'Despesa', 'Parent_ID': variaveisId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Despesas Eventuais', 'Cor_Hexadecimal': '#FFC107', 'Tipo': 'Despesa', 'Parent_ID': variaveisId});

    String patrimonioId = await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': 'Patrimônio', 'Cor_Hexadecimal': '#673AB7', 'Tipo': 'Despesa', 'Oculta': 0, 'Ordem': 7
    });
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Aportes em Investimentos', 'Cor_Hexadecimal': '#673AB7', 'Tipo': 'Despesa', 'Parent_ID': patrimonioId});

    // --- MERCADO (Despesas Focadas) ---
    String mercadoId = await db.insert(SupabaseHelper.tableCategorias, {
      'Nome': 'Mercado', 'Cor_Hexadecimal': '#F44336', 'Tipo': 'Despesa', 'Oculta': 0, 'Ordem': 8
    });
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Açougue e Peixaria', 'Cor_Hexadecimal': '#F44336', 'Tipo': 'Despesa', 'Parent_ID': mercadoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Laticínios e Frios', 'Cor_Hexadecimal': '#F44336', 'Tipo': 'Despesa', 'Parent_ID': mercadoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Mercearia Básica', 'Cor_Hexadecimal': '#F44336', 'Tipo': 'Despesa', 'Parent_ID': mercadoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Hortifruti', 'Cor_Hexadecimal': '#F44336', 'Tipo': 'Despesa', 'Parent_ID': mercadoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Padaria e Matinais', 'Cor_Hexadecimal': '#F44336', 'Tipo': 'Despesa', 'Parent_ID': mercadoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Biscoitos e Guloseimas', 'Cor_Hexadecimal': '#F44336', 'Tipo': 'Despesa', 'Parent_ID': mercadoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Bebidas', 'Cor_Hexadecimal': '#F44336', 'Tipo': 'Despesa', 'Parent_ID': mercadoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Higiene Pessoal', 'Cor_Hexadecimal': '#F44336', 'Tipo': 'Despesa', 'Parent_ID': mercadoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Limpeza da Casa', 'Cor_Hexadecimal': '#F44336', 'Tipo': 'Despesa', 'Parent_ID': mercadoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Congelados e Prontos', 'Cor_Hexadecimal': '#F44336', 'Tipo': 'Despesa', 'Parent_ID': mercadoId});
    await db.insert(SupabaseHelper.tableCategorias, {'Nome': 'Pet Shop', 'Cor_Hexadecimal': '#F44336', 'Tipo': 'Despesa', 'Parent_ID': mercadoId});
  }
}
