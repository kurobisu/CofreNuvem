-- ============================================================
-- Diagnostico: usuario "Antonio" apagado enquanto ainda tinha
-- contas/metodos/transacoes vinculados (residuo do bug de
-- isolamento familiar corrigido em scripts/fix_usuarios_family_isolation.sql).
-- Somente leitura -- nao altera nada.
-- ============================================================

select json_build_object(
  -- Todas as linhas em usuarios com nome parecido, incluindo apagadas
  'usuarios_antonio', (
    select json_agg(json_build_object(
      'id', id, 'nome', nome, 'auth_id', auth_id, 'is_fantasma', is_fantasma,
      'deleted_at', deleted_at, 'updated_at', updated_at
    ) order by deleted_at nulls last, updated_at)
    from public.usuarios
    where nome ilike '%ant%nio%'
  ),
  -- Contas bancarias cujo usuario_id nao aponta pra nenhum usuario vivo
  'contas_orfas', (
    select json_agg(json_build_object('id', c.id, 'nome', c.nome, 'usuario_id', c.usuario_id))
    from public.contas_bancarias c
    where c.deleted_at is null
      and c.usuario_id is not null
      and not exists (select 1 from public.usuarios u where u.id = c.usuario_id and u.deleted_at is null)
  ),
  -- Transacoes cujo usuario_id nao aponta pra nenhum usuario vivo
  'transacoes_orfas', (
    select json_agg(json_build_object('id', t.id, 'descricao', t.descricao, 'valor', t.valor, 'usuario_id', t.usuario_id))
    from public.transacoes t
    where t.deleted_at is null
      and t.usuario_id is not null
      and not exists (select 1 from public.usuarios u where u.id = t.usuario_id and u.deleted_at is null)
  ),
  -- Investimentos cujo usuario_id nao aponta pra nenhum usuario vivo
  'investimentos_orfaos', (
    select json_agg(json_build_object('id', i.id, 'ativo', i.ativo, 'usuario_id', i.usuario_id))
    from public.investimentos i
    where i.deleted_at is null
      and i.usuario_id is not null
      and not exists (select 1 from public.usuarios u where u.id = i.usuario_id and u.deleted_at is null)
  )
) as diagnostico;
