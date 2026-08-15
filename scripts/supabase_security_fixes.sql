-- ============================================================
-- Supabase Security Fixes
-- Aplicar no SQL Editor do Supabase (Dashboard) na ordem abaixo.
-- Esses ajustes resolvem os erros/warnings do Database Linter
-- sem quebrar o app CofreNuvem.
-- ============================================================

-- ------------------------------------------------------------
-- 1. RLS Disabled in Public (ERROR)
--    As tabelas de familia sao acessadas apenas via funcoes RPC
--    SECURITY DEFINER. Habilitar RLS nao afeta essas funcoes,
--    mas protege contra acesso direto nao autorizado.
-- ------------------------------------------------------------
ALTER TABLE public.familias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.familia_membros ENABLE ROW LEVEL SECURITY;

-- Opcional: forca RLS tambem para o dono da tabela (boa pratica).
-- Remova se houver algum processo interno que precise acessar
-- essas tabelas diretamente como postgres/service_role.
ALTER TABLE public.familias FORCE ROW LEVEL SECURITY;
ALTER TABLE public.familia_membros FORCE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 2. Function Search Path Mutable (WARN)
--    Define search_path vazio nas funcoes expostas para evitar
--    ataques de search_path hijacking.
-- ------------------------------------------------------------
ALTER FUNCTION public.handle_new_user_family() SET search_path = '';
ALTER FUNCTION public.invite_user_by_email(text) SET search_path = '';
ALTER FUNCTION public.get_my_family_auth_ids() SET search_path = '';
ALTER FUNCTION public.get_pending_invites() SET search_path = '';
ALTER FUNCTION public.accept_family_invite(uuid) SET search_path = '';
ALTER FUNCTION public.reject_family_invite(uuid) SET search_path = '';

-- ------------------------------------------------------------
-- 3. SECURITY DEFINER Function Executable by anon (WARN)
--    Usuarios nao autenticados (anon) nao devem chamar essas
--    funcoes. O app so as chama quando o usuario esta logado.
-- ------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.handle_new_user_family() FROM anon;
REVOKE EXECUTE ON FUNCTION public.invite_user_by_email(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_my_family_auth_ids() FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_pending_invites() FROM anon;
REVOKE EXECUTE ON FUNCTION public.accept_family_invite(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.reject_family_invite(uuid) FROM anon;

-- ------------------------------------------------------------
-- 4. Garantir EXECUTE para usuarios autenticados
--    O app chama essas funcoes via RPC com role authenticated.
--    NAO revogue de authenticated, senao o compartilhamento
--    familiar para de funcionar.
-- ------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.handle_new_user_family() TO authenticated;
GRANT EXECUTE ON FUNCTION public.invite_user_by_email(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_family_auth_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_invites() TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_family_invite(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_family_invite(uuid) TO authenticated;

-- ------------------------------------------------------------
-- 5. Leaked Password Protection (WARN)
--    Nao e possivel habilitar via SQL. Va em:
--    Supabase Dashboard -> Authentication -> Providers
--    -> Leaked Password Protection -> Enabled
-- ------------------------------------------------------------
