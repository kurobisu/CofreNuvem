-- ============================================================
-- Fix: usuarios.auth_id NULL leak (cross-family data exposure)
-- Aplicar no SQL Editor do Supabase (Dashboard).
--
-- Causa raiz: o app nunca preenchia usuarios.auth_id ao criar um
-- perfil (onboarding) ou usuario fantasma, e a coluna nao tinha
-- DEFAULT. Como toda linha ficava com auth_id NULL, a policy
-- "Permissao_Usuarios" precisou de um escape "OR auth_id IS NULL"
-- para o dono conseguir ver o proprio perfil -- o que, como efeito
-- colateral, tornava TODAS as linhas de usuarios (de QUALQUER
-- familia) visiveis para QUALQUER usuario autenticado.
--
-- Este script:
--   1) Preenche auth_id nas linhas existentes, inferindo o dono
--      a partir das contas/transacoes/investimentos vinculados.
--   2) Aborta (ROLLBACK) se sobrar alguma linha sem inferencia
--      possivel, para nunca aplicar a policy nova com dados
--      inconsistentes.
--   3) Trava a coluna (DEFAULT auth.uid() + NOT NULL).
--   4) Substitui a policy removendo o "OR auth_id IS NULL".
-- ============================================================

begin;

-- 1) Backfill: para cada usuario sem auth_id, usa o auth_id mais
--    frequente entre suas contas bancarias, transacoes e investimentos.
with candidate as (
  select usuario_id, auth_id, count(*) as cnt
  from (
    select usuario_id, auth_id from public.contas_bancarias where usuario_id is not null
    union all
    select usuario_id, auth_id from public.transacoes where usuario_id is not null
    union all
    select usuario_id, auth_id from public.investimentos where usuario_id is not null
  ) x
  group by usuario_id, auth_id
),
ranked as (
  select usuario_id, auth_id,
         row_number() over (partition by usuario_id order by cnt desc) as rn
  from candidate
)
update public.usuarios u
set auth_id = r.auth_id
from ranked r
where r.usuario_id = u.id
  and r.rn = 1
  and u.auth_id is null;

-- 2) Trava de seguranca: aborta a migracao inteira (ROLLBACK) se
--    sobrar alguma linha sem auth_id (perfil sem nenhuma conta,
--    transacao ou investimento vinculado -- nao ha como inferir
--    automaticamente). Rode a query abaixo manualmente para ver
--    quais linhas sao essas, atribua o auth_id correto com um
--    UPDATE manual e rode este script de novo.
--
--    select id, nome, is_fantasma from public.usuarios where auth_id is null;
do $$
declare
  remaining int;
begin
  select count(*) into remaining from public.usuarios where auth_id is null;
  if remaining > 0 then
    raise exception 'Abortando: % linha(s) em usuarios continuam com auth_id NULL. Atribua manualmente (ex: update public.usuarios set auth_id = ''<uuid>'' where id = ''<uuid>'';) e rode este script novamente.', remaining;
  end if;
end $$;

-- 3) A partir de agora, todo INSERT sem auth_id explicito recebe o
--    auth.uid() de quem esta fazendo a chamada (mesmo padrao das
--    outras tabelas), e a coluna nunca mais pode ficar NULL.
alter table public.usuarios alter column auth_id set default auth.uid();
alter table public.usuarios alter column auth_id set not null;

-- 4) Policy corrigida: mesmo padrao "Compartilhamento" usado nas
--    demais tabelas, sem a brecha "OR auth_id IS NULL".
drop policy if exists "Permissao_Usuarios" on public.usuarios;
create policy "Permissao_Usuarios" on public.usuarios
  for all
  using (auth_id = auth.uid() or auth_id in (select get_my_family_auth_ids()))
  with check (auth_id = auth.uid() or auth_id in (select get_my_family_auth_ids()));

commit;

-- ------------------------------------------------------------
-- Verificacao pos-migracao (rode separadamente, so leitura):
--
-- select id, nome, is_fantasma, auth_id from public.usuarios order by nome;
--
-- select policyname, cmd, qual, with_check from pg_policies
-- where schemaname = 'public' and tablename = 'usuarios';
-- ------------------------------------------------------------
