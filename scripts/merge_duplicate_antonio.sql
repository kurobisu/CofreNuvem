-- ============================================================
-- Migra as transacoes do Antonio duplicado (33f889a9...) pro
-- Antonio original (65b281d9...), redireciona a conta/metodo
-- "Dinheiro" das transacoes para a conta "Dinheiro" ja existente
-- do original, apaga a conta/metodo duplicados (agora vazios) e
-- por fim apaga o usuario duplicado. Tudo em uma transacao --
-- se qualquer verificacao falhar, nada e alterado.
-- ============================================================

begin;

do $$
declare
  orig_antonio uuid := '65b281d9-83bd-40ba-8caf-98c624d7dcd6';
  dup_antonio uuid := '33f889a9-f855-4593-9f8a-3f108a1dbf7a';
  dup_conta uuid := '02fa0b26-75c8-4e6c-b58a-10dfb3f6e6a0';
  orig_conta uuid;
  dup_metodo uuid;
  orig_metodo uuid;
  moved int;
begin
  select id into orig_conta
  from public.contas_bancarias
  where usuario_id = orig_antonio and nome = 'Dinheiro' and codigo_banco = '100' and deleted_at is null
  order by updated_at asc
  limit 1;

  if orig_conta is null then
    raise exception 'Abortando: nao achei a conta Dinheiro do Antonio original.';
  end if;

  select id into dup_metodo from public.metodos_pagamento where conta_id = dup_conta and deleted_at is null limit 1;
  select id into orig_metodo from public.metodos_pagamento where conta_id = orig_conta and deleted_at is null limit 1;

  if orig_metodo is null then
    raise exception 'Abortando: nao achei o metodo de pagamento Dinheiro do Antonio original.';
  end if;

  update public.transacoes
  set usuario_id = orig_antonio,
      conta_id = orig_conta,
      metodo_id = orig_metodo
  where usuario_id = dup_antonio;
  get diagnostics moved = row_count;

  if moved <> 3 then
    raise exception 'Abortando: esperava migrar 3 transacoes, migrei %. Revise manualmente.', moved;
  end if;

  update public.contas_bancarias set deleted_at = timezone('utc'::text, now()) where id = dup_conta;
  if dup_metodo is not null then
    update public.metodos_pagamento set deleted_at = timezone('utc'::text, now()) where id = dup_metodo;
  end if;

  update public.usuarios set deleted_at = timezone('utc'::text, now()) where id = dup_antonio;
end $$;

commit;

-- Verificacao
select id, descricao, valor, tipo, data, usuario_id, conta_id, metodo_id
from public.transacoes
where usuario_id = '65b281d9-83bd-40ba-8caf-98c624d7dcd6'
order by updated_at desc
limit 10;

select id, nome, deleted_at from public.usuarios where nome ilike '%ant%nio%';
