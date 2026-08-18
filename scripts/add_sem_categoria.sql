-- Categoria "coringa" pra produtos novos criados sem categoria escolhida.
-- produtos_catalogo.categoria_id e NOT NULL, entao o app precisa de um id
-- valido pra usar como fallback quando o usuario nao seleciona categoria
-- na hora de criar um produto novo direto da Lista de Compras.
--
-- categorias_produtos so tem policy de SELECT (leitura publica), entao o
-- app nao consegue criar essa linha sozinho -- rode este script uma vez no
-- SQL Editor do Supabase.

insert into public.categorias_produtos (nome, grupo, emoji, ordem)
select 'Sem categoria', 'Outros', '📦', 999
where not exists (
  select 1 from public.categorias_produtos where nome = 'Sem categoria'
);
