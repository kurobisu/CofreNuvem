-- Vincula uma lista de compras concluida a transacao financeira criada no
-- momento do "Finalizar compra". Ate agora so o ITEM (lista_compras) sabia
-- a que transacao pertencia (Transacao_ID, gravado por transaction_form_screen
-- ao salvar); a lista em si nao guardava nada, entao nao tinha como
-- recalcular o valor da transacao quando a lista era editada depois de
-- concluida, nem como saber qual transacao excluir junto se a lista fosse
-- apagada.

alter table public.listas_compras
  add column if not exists transacao_id uuid references public.transacoes(id);

create index if not exists idx_listas_compras_transacao_id
  on public.listas_compras(transacao_id)
  where transacao_id is not null;
