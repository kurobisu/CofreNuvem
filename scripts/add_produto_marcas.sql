-- ============================================================
-- Marcas como sub-registro do produto do catalogo (ex: o produto
-- "Cafe" pode ter as marcas "NesCafe" e "Sao Braz", cada uma com seu
-- proprio historico de preco) -- substitui o campo de texto livre
-- produtos_catalogo.marca, que nao suportava preco por marca.
--
-- Aplicar no SQL Editor do Supabase (Dashboard). Roda tudo numa
-- transacao -- se algo falhar, nada fica alterado.
--
-- Nao apaga nem migra a coluna produtos_catalogo.marca (fica sem uso
-- dai pra frente) -- nao ha dado real registrado nela hoje.
-- ============================================================

begin;

create table if not exists public.produto_marcas (
  id uuid primary key default gen_random_uuid(),
  auth_id uuid not null default auth.uid(),
  produto_id uuid not null references public.produtos_catalogo(id),
  nome text not null,
  updated_at timestamptz not null default timezone('utc'::text, now()),
  deleted_at timestamptz
);

alter table public.produto_marcas enable row level security;
drop policy if exists "Compartilhamento" on public.produto_marcas;
create policy "Compartilhamento" on public.produto_marcas
  for all
  using (auth_id in (select get_my_family_auth_ids()) or auth_id = auth.uid())
  with check (auth_id in (select get_my_family_auth_ids()) or auth_id = auth.uid());

create index if not exists idx_produto_marcas_produto_id
  on public.produto_marcas(produto_id)
  where deleted_at is null;

-- lista_compras.preco ja registra o historico de preco por item; adicionar
-- marca_id aqui permite filtrar esse historico por (produto_id, marca_id)
-- em vez de so produto_id, sem precisar de uma tabela de preco separada.
alter table public.lista_compras
  add column if not exists marca_id uuid references public.produto_marcas(id);

commit;
