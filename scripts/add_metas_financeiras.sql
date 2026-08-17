-- ============================================================
-- Feature: Metas Financeiras (Financial Goals)
-- Aplicar no SQL Editor do Supabase (Dashboard).
--
-- Segue exatamente o mesmo padrao de isolamento familiar das
-- demais tabelas (auth_id + policy "Compartilhamento" usando
-- get_my_family_auth_ids()), entao nao exige nenhuma mudanca
-- na arquitetura de familia/RLS ja existente.
-- ============================================================

create table if not exists public.metas (
  id uuid primary key default gen_random_uuid(),
  auth_id uuid not null default auth.uid(),
  nome text not null,
  valor_alvo numeric not null,
  aporte_mensal_planejado numeric,
  data_alvo date,
  icone text not null default 'flag',
  cor_hexadecimal text not null default '#4CAF50',
  status text not null default 'Ativa',
  ordem integer not null default 0,
  updated_at timestamptz not null default timezone('utc'::text, now()),
  deleted_at timestamptz
);

alter table public.metas enable row level security;

drop policy if exists "Compartilhamento" on public.metas;
create policy "Compartilhamento" on public.metas
  for all
  using (auth_id in (select get_my_family_auth_ids()) or auth_id = auth.uid())
  with check (auth_id in (select get_my_family_auth_ids()) or auth_id = auth.uid());

-- Mesmo tratamento de search_path/anon aplicado as demais funcoes
-- em scripts/supabase_security_fixes.sql nao se aplica aqui: esta
-- tabela e acessada via PostgREST direto (select/insert/update),
-- nao via RPC SECURITY DEFINER.
