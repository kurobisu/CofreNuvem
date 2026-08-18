-- ============================================================
-- Repaginacao do modulo de Compras: multiplas listas nomeadas +
-- catalogo de produtos com categorias/tags/emoji.
--
-- Aplicar no SQL Editor do Supabase (Dashboard). Roda tudo numa
-- transacao -- se algo falhar, nada fica alterado.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1) listas_compras: uma linha por lista nomeada (ex: "Mantimentos",
--    "17/08"). Mesmo padrao de isolamento familiar das demais tabelas.
-- ------------------------------------------------------------
create table if not exists public.listas_compras (
  id uuid primary key default gen_random_uuid(),
  auth_id uuid not null default auth.uid(),
  nome text not null,
  status text not null default 'Ativa', -- 'Ativa' | 'Concluida'
  updated_at timestamptz not null default timezone('utc'::text, now()),
  deleted_at timestamptz
);

alter table public.listas_compras enable row level security;
drop policy if exists "Compartilhamento" on public.listas_compras;
create policy "Compartilhamento" on public.listas_compras
  for all
  using (auth_id in (select get_my_family_auth_ids()) or auth_id = auth.uid())
  with check (auth_id in (select get_my_family_auth_ids()) or auth_id = auth.uid());

-- ------------------------------------------------------------
-- 2) categorias_produtos: grupos/categorias do catalogo (ex:
--    "Frutas e vegetais" dentro do grupo "Alimentos"). Dados de
--    referencia globais, iguais pra todo mundo -- so leitura.
-- ------------------------------------------------------------
create table if not exists public.categorias_produtos (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  grupo text not null,
  emoji text not null,
  ordem integer not null default 0
);

alter table public.categorias_produtos enable row level security;
drop policy if exists "Leitura publica" on public.categorias_produtos;
create policy "Leitura publica" on public.categorias_produtos
  for select to authenticated using (true);

-- ------------------------------------------------------------
-- 3) produtos_catalogo: itens do catalogo. auth_id nulo = produto
--    do sistema (visivel pra todo mundo); auth_id preenchido =
--    produto customizado, visivel so pra familia de quem criou.
-- ------------------------------------------------------------
create table if not exists public.produtos_catalogo (
  id uuid primary key default gen_random_uuid(),
  auth_id uuid,
  categoria_id uuid not null references public.categorias_produtos(id),
  nome text not null,
  emoji text not null,
  tags text[] not null default '{}',
  unidade_padrao text not null default 'Unidade',
  updated_at timestamptz not null default timezone('utc'::text, now()),
  deleted_at timestamptz
);

alter table public.produtos_catalogo enable row level security;
drop policy if exists "Compartilhamento" on public.produtos_catalogo;
create policy "Compartilhamento" on public.produtos_catalogo
  for all
  using (auth_id is null or auth_id in (select get_my_family_auth_ids()) or auth_id = auth.uid())
  with check (auth_id in (select get_my_family_auth_ids()) or auth_id = auth.uid());

-- ------------------------------------------------------------
-- 4) lista_compras (tabela existente): adiciona vinculo com a
--    lista, com o produto do catalogo, e a unidade de medida.
-- ------------------------------------------------------------
alter table public.lista_compras add column if not exists lista_id uuid references public.listas_compras(id);
alter table public.lista_compras add column if not exists produto_id uuid references public.produtos_catalogo(id);
alter table public.lista_compras add column if not exists unidade text not null default 'Unidade';

-- ------------------------------------------------------------
-- 5) Backfill dos dados existentes.
--    5a) Remove os artefatos do sistema antigo de "biblioteca por
--        nome" (linhas sentinela que nunca foram itens de compra
--        de verdade: comprado=-1 marcava categoria de produto,
--        comprado=2 marcava "cadastrado na biblioteca").
-- ------------------------------------------------------------
update public.lista_compras
set deleted_at = timezone('utc'::text, now())
where deleted_at is null
  and (comprado in (-1, 2) or nome like 'prod_cat:%');

--    5b) Cria uma lista "Compras" padrao pra cada auth_id que tem
--        itens reais sem lista_id, e vincula esses itens a ela.
do $$
declare
  r record;
  nova_lista_id uuid;
begin
  for r in
    select distinct auth_id
    from public.lista_compras
    where lista_id is null and deleted_at is null and auth_id is not null
  loop
    insert into public.listas_compras (auth_id, nome, status)
    values (r.auth_id, 'Compras', 'Ativa')
    returning id into nova_lista_id;

    update public.lista_compras
    set lista_id = nova_lista_id
    where auth_id = r.auth_id and lista_id is null and deleted_at is null;
  end loop;
end $$;

-- ------------------------------------------------------------
-- 6) Seed: categorias do catalogo (dados de referencia globais).
-- ------------------------------------------------------------
insert into public.categorias_produtos (nome, grupo, emoji, ordem) values
  ('Frutas e vegetais', 'Alimentos', '🥦', 0),
  ('Padaria', 'Alimentos', '🍞', 1),
  ('Produtos de confeitaria', 'Alimentos', '🧁', 2),
  ('Leite e ovos', 'Alimentos', '🧀', 3),
  ('Produtos secos', 'Alimentos', '🍝', 4),
  ('Refeições prontas', 'Alimentos', '🍱', 5),
  ('Peixes e frutos do mar', 'Alimentos', '🐟', 6),
  ('Congelados', 'Alimentos', '❄️', 7),
  ('Enlatados e potes', 'Alimentos', '🥫', 8),
  ('Bebidas', 'Bebidas', '🥤', 9),
  ('Café e chá', 'Bebidas', '☕', 10),
  ('Álcoois', 'Bebidas', '🍷', 11),
  ('Cuidados pessoais', 'Cuidados Pessoais e Saúde', '🧴', 12),
  ('Bebê', 'Cuidados Pessoais e Saúde', '🧸', 13),
  ('Saúde', 'Cuidados Pessoais e Saúde', '💊', 14),
  ('Roupas', 'Casa e Estilo de Vida', '👕', 15),
  ('Casa e jardim', 'Casa e Estilo de Vida', '💐', 16),
  ('Limpeza e lavanderia', 'Casa e Estilo de Vida', '🧽', 17),
  ('Papelaria', 'Casa e Estilo de Vida', '📝', 18),
  ('Animais de estimação', 'Outro', '🦴', 19)
on conflict do nothing;

-- ------------------------------------------------------------
-- 7) Seed: produtos (catalogo minimo pra validar o sistema --
--    3 a 5 produtos por categoria; o restante fica pra completar
--    depois). auth_id nulo = produto do sistema, visivel a todos.
-- ------------------------------------------------------------
insert into public.produtos_catalogo (categoria_id, nome, emoji, tags, unidade_padrao)
select c.id, p.nome, p.emoji, p.tags::text[], p.unidade
from (values
  -- Frutas e vegetais
  ('Frutas e vegetais', 'Maçã', '🍎', array['Vegetariano','Vegano','Sem Glúten'], 'Unidade'),
  ('Frutas e vegetais', 'Banana', '🍌', array['Vegetariano','Vegano','Sem Glúten'], 'Unidade'),
  ('Frutas e vegetais', 'Tomate', '🍅', array['Vegetariano','Vegano','Sem Glúten'], 'Kg'),
  ('Frutas e vegetais', 'Alface', '🥬', array['Vegetariano','Vegano','Sem Glúten','Keto'], 'Unidade'),
  ('Frutas e vegetais', 'Cenoura', '🥕', array['Vegetariano','Vegano','Sem Glúten'], 'Kg'),
  -- Padaria
  ('Padaria', 'Pão Francês', '🥖', array['Vegetariano'], 'Kg'),
  ('Padaria', 'Pão de Forma', '🍞', array['Vegetariano'], 'Unidade'),
  ('Padaria', 'Croissant', '🥐', array['Vegetariano'], 'Unidade'),
  -- Produtos de confeitaria
  ('Produtos de confeitaria', 'Bolo de Chocolate', '🍰', array['Vegetariano'], 'Unidade'),
  ('Produtos de confeitaria', 'Brigadeiro', '🍬', array['Vegetariano','Sem Glúten'], 'Unidade'),
  ('Produtos de confeitaria', 'Biscoito Recheado', '🍪', array['Vegetariano'], 'Unidade'),
  -- Leite e ovos
  ('Leite e ovos', 'Leite Integral', '🥛', array['Vegetariano'], 'Litro'),
  ('Leite e ovos', 'Queijo Mussarela', '🧀', array['Vegetariano','Keto'], 'Kg'),
  ('Leite e ovos', 'Ovos', '🥚', array['Vegetariano','Keto','Sem Glúten','Alto teor de proteína'], 'Unidade'),
  ('Leite e ovos', 'Manteiga', '🧈', array['Vegetariano','Keto','Sem Glúten'], 'Unidade'),
  -- Produtos secos
  ('Produtos secos', 'Arroz', '🍚', array['Vegetariano','Vegano','Sem Glúten'], 'Kg'),
  ('Produtos secos', 'Feijão', '🫘', array['Vegetariano','Vegano','Sem Glúten','Alto teor de proteína'], 'Kg'),
  ('Produtos secos', 'Macarrão', '🍝', array['Vegetariano','Vegano'], 'Unidade'),
  ('Produtos secos', 'Farinha de Trigo', '🌾', array['Vegetariano','Vegano'], 'Kg'),
  -- Refeições prontas
  ('Refeições prontas', 'Marmita Pronta', '🍱', array[]::text[], 'Unidade'),
  ('Refeições prontas', 'Pizza Congelada', '🍕', array['Vegetariano'], 'Unidade'),
  ('Refeições prontas', 'Nuggets', '🍗', array['Congelador'], 'Unidade'),
  -- Peixes e frutos do mar
  ('Peixes e frutos do mar', 'Salmão', '🐟', array['Sem Glúten','Keto','Alto teor de proteína'], 'Kg'),
  ('Peixes e frutos do mar', 'Camarão', '🦐', array['Sem Glúten','Keto','Alto teor de proteína'], 'Kg'),
  ('Peixes e frutos do mar', 'Atum em Lata', '🥫', array['Sem Glúten','Keto','Alto teor de proteína'], 'Unidade'),
  -- Congelados
  ('Congelados', 'Vegetais Congelados', '🥦', array['Vegetariano','Vegano','Sem Glúten','Congelador'], 'Unidade'),
  ('Congelados', 'Batata Frita Congelada', '🍟', array['Vegetariano','Vegano','Congelador'], 'Unidade'),
  ('Congelados', 'Polpa de Fruta', '🧊', array['Vegetariano','Vegano','Sem Glúten','Congelador'], 'Unidade'),
  -- Enlatados e potes
  ('Enlatados e potes', 'Milho em Lata', '🌽', array['Vegetariano','Vegano','Sem Glúten'], 'Unidade'),
  ('Enlatados e potes', 'Ervilha em Lata', '🫛', array['Vegetariano','Vegano','Sem Glúten'], 'Unidade'),
  ('Enlatados e potes', 'Extrato de Tomate', '🥫', array['Vegetariano','Vegano','Sem Glúten'], 'Unidade'),
  -- Bebidas
  ('Bebidas', 'Água Mineral', '💧', array['Vegetariano','Vegano','Sem Glúten'], 'Unidade'),
  ('Bebidas', 'Refrigerante', '🥤', array['Vegetariano','Vegano'], 'Unidade'),
  ('Bebidas', 'Suco de Laranja', '🍊', array['Vegetariano','Vegano','Sem Glúten'], 'Litro'),
  -- Café e chá
  ('Café e chá', 'Café em Pó', '☕', array['Vegetariano','Vegano','Sem Glúten'], 'Unidade'),
  ('Café e chá', 'Chá Verde', '🍵', array['Vegetariano','Vegano','Sem Glúten'], 'Unidade'),
  ('Café e chá', 'Achocolatado', '🍫', array['Vegetariano'], 'Unidade'),
  -- Álcoois
  ('Álcoois', 'Cerveja', '🍺', array['Vegano'], 'Unidade'),
  ('Álcoois', 'Vinho Tinto', '🍷', array['Vegano','Sem Glúten'], 'Unidade'),
  ('Álcoois', 'Vodka', '🍸', array['Vegano','Sem Glúten'], 'Unidade'),
  -- Cuidados pessoais
  ('Cuidados pessoais', 'Sabonete', '🧼', array[]::text[], 'Unidade'),
  ('Cuidados pessoais', 'Shampoo', '🧴', array[]::text[], 'Unidade'),
  ('Cuidados pessoais', 'Pasta de Dente', '🪥', array[]::text[], 'Unidade'),
  -- Bebê
  ('Bebê', 'Fralda', '🧷', array[]::text[], 'Unidade'),
  ('Bebê', 'Mamadeira', '🍼', array[]::text[], 'Unidade'),
  ('Bebê', 'Lenço Umedecido', '🧻', array[]::text[], 'Unidade'),
  -- Saúde
  ('Saúde', 'Analgésico', '💊', array[]::text[], 'Unidade'),
  ('Saúde', 'Álcool em Gel', '🧴', array[]::text[], 'Unidade'),
  ('Saúde', 'Curativo', '🩹', array[]::text[], 'Unidade'),
  -- Roupas
  ('Roupas', 'Camiseta', '👕', array[]::text[], 'Unidade'),
  ('Roupas', 'Meias', '🧦', array[]::text[], 'Unidade'),
  ('Roupas', 'Calça Jeans', '👖', array[]::text[], 'Unidade'),
  -- Casa e jardim
  ('Casa e jardim', 'Vaso de Planta', '🪴', array[]::text[], 'Unidade'),
  ('Casa e jardim', 'Flores', '💐', array[]::text[], 'Unidade'),
  ('Casa e jardim', 'Lâmpada', '💡', array[]::text[], 'Unidade'),
  -- Limpeza e lavanderia
  ('Limpeza e lavanderia', 'Detergente', '🧴', array[]::text[], 'Unidade'),
  ('Limpeza e lavanderia', 'Sabão em Pó', '🧺', array[]::text[], 'Unidade'),
  ('Limpeza e lavanderia', 'Desinfetante', '🧽', array[]::text[], 'Unidade'),
  -- Papelaria
  ('Papelaria', 'Caneta', '🖊️', array[]::text[], 'Unidade'),
  ('Papelaria', 'Caderno', '📓', array[]::text[], 'Unidade'),
  ('Papelaria', 'Post-it', '📝', array[]::text[], 'Unidade'),
  -- Animais de estimação
  ('Animais de estimação', 'Ração', '🦴', array[]::text[], 'Kg'),
  ('Animais de estimação', 'Areia Sanitária', '🐾', array[]::text[], 'Kg'),
  ('Animais de estimação', 'Brinquedo Pet', '🎾', array[]::text[], 'Unidade')
) as p(categoria_nome, nome, emoji, tags, unidade)
join public.categorias_produtos c on c.nome = p.categoria_nome
on conflict do nothing;

commit;

-- ------------------------------------------------------------
-- Verificacao pos-migracao (rode separadamente, so leitura):
--
-- select count(*) from public.categorias_produtos;
-- select count(*) from public.produtos_catalogo;
-- select id, nome, status from public.listas_compras;
-- select count(*) from public.lista_compras where lista_id is null and deleted_at is null;
-- ------------------------------------------------------------
