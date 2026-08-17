-- ============================================================
-- Restaura o usuario "Vinicius" (usuario real, nao fantasma,
-- apagado no mesmo incidente do Antonio) e varre a base inteira
-- em busca de qualquer outro usuario apagado que ainda tenha
-- contas/transacoes/investimentos vinculados vivos.
-- ============================================================

update public.usuarios
set deleted_at = null
where id = '80bc7970-8a14-46d8-829d-63588f46e5eb';

-- Varredura: qualquer usuario apagado (de qualquer familia visivel
-- a este login) que ainda tenha algo vinculado e vivo apontando pra ele.
select
  u.id, u.nome, u.auth_id, u.is_fantasma, u.deleted_at,
  (select count(*) from public.contas_bancarias c where c.usuario_id = u.id and c.deleted_at is null) as contas_vivas,
  (select count(*) from public.transacoes t where t.usuario_id = u.id and t.deleted_at is null) as transacoes_vivas,
  (select count(*) from public.investimentos i where i.usuario_id = u.id and i.deleted_at is null) as investimentos_vivos
from public.usuarios u
where u.deleted_at is not null
  and (
    exists (select 1 from public.contas_bancarias c where c.usuario_id = u.id and c.deleted_at is null)
    or exists (select 1 from public.transacoes t where t.usuario_id = u.id and t.deleted_at is null)
    or exists (select 1 from public.investimentos i where i.usuario_id = u.id and i.deleted_at is null)
  );
