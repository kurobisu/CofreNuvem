-- ============================================================
-- Mostra exatamente o que esta vinculado ao Antonio duplicado
-- (33f889a9...) antes de decidir apagar ou migrar pro original.
-- Somente leitura.
-- ============================================================

select json_build_object(
  'contas', (
    select json_agg(json_build_object('id', id, 'nome', nome, 'codigo_banco', codigo_banco, 'updated_at', updated_at))
    from public.contas_bancarias
    where usuario_id = '33f889a9-f855-4593-9f8a-3f108a1dbf7a' and deleted_at is null
  ),
  'transacoes', (
    select json_agg(json_build_object('id', id, 'descricao', descricao, 'valor', valor, 'tipo', tipo, 'data', data, 'updated_at', updated_at))
    from public.transacoes
    where usuario_id = '33f889a9-f855-4593-9f8a-3f108a1dbf7a' and deleted_at is null
  ),
  'investimentos', (
    select json_agg(json_build_object('id', id, 'ativo', ativo, 'valor_investido', valor_investido, 'updated_at', updated_at))
    from public.investimentos
    where usuario_id = '33f889a9-f855-4593-9f8a-3f108a1dbf7a' and deleted_at is null
  )
) as detalhes;
