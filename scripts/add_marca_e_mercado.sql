-- Duas colunas novas pro pedido de "Marcas" e "Mercado":
--
-- 1) produtos_catalogo.marca: texto opcional pra diferenciar o mesmo
--    produto entre marcas diferentes (ex: "Extrato de Tomate" Quero vs
--    Bonari continuam sendo dois produtos separados no catálogo, cada um
--    com seu próprio histórico de preço -- essa coluna só guarda o nome da
--    marca pra exibir/filtrar).
--
-- 2) listas_compras.mercado: texto opcional com o nome do mercado/loja
--    onde aquela lista foi/será comprada, pra poder filtrar os Relatórios
--    por origem.

alter table public.produtos_catalogo add column if not exists marca text;
alter table public.listas_compras add column if not exists mercado text;
