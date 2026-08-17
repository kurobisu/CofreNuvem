-- ============================================================
-- Apaga o Antonio duplicado (criado por engano apos a restauracao
-- do Antonio original). So executa se ele realmente nao tiver
-- nada vinculado -- aborta com erro caso contrario, por seguranca.
-- ============================================================

do $$
declare
  linked int;
begin
  select
    (select count(*) from public.contas_bancarias where usuario_id = '33f889a9-f855-4593-9f8a-3f108a1dbf7a' and deleted_at is null)
  + (select count(*) from public.transacoes where usuario_id = '33f889a9-f855-4593-9f8a-3f108a1dbf7a' and deleted_at is null)
  + (select count(*) from public.investimentos where usuario_id = '33f889a9-f855-4593-9f8a-3f108a1dbf7a' and deleted_at is null)
  into linked;

  if linked > 0 then
    raise exception 'Abortando: o Antonio duplicado (33f889a9...) tem % registro(s) vinculado(s). Nao vou apagar -- verifique manualmente.', linked;
  end if;
end $$;

update public.usuarios
set deleted_at = timezone('utc'::text, now())
where id = '33f889a9-f855-4593-9f8a-3f108a1dbf7a';

-- Verificacao final: so deve sobrar 1 Antonio (o original, vivo).
select id, nome, deleted_at from public.usuarios where nome ilike '%ant%nio%';
