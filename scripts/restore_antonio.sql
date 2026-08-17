-- ============================================================
-- Repara: reverte a exclusao acidental do usuario "Antonio"
-- original, que deixou contas/transacoes vinculadas orfas.
-- Nao reescreve nenhum dado -- so remove o deleted_at.
-- ============================================================

update public.usuarios
set deleted_at = null
where id = '65b281d9-83bd-40ba-8caf-98c624d7dcd6';

-- Verificacao: confirma que o Antonio original voltou e investiga
-- a outra conta orfa (usuario_id diferente, nao e o Antonio).
select id, nome, auth_id, is_fantasma, deleted_at
from public.usuarios
where id in ('65b281d9-83bd-40ba-8caf-98c624d7dcd6', '80bc7970-8a14-46d8-829d-63588f46e5eb');
