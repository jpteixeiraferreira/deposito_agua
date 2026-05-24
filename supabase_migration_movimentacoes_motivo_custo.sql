-- Execute no SQL Editor do Supabase para estruturar melhor a auditoria de estoque.
-- O aplicativo ja grava o motivo padronizado na observacao; estes campos deixam
-- o historico pronto para relatorios que nao dependem do custo atual do produto.

alter table public.movimentacoes_estoque
  add column if not exists motivo text,
  add column if not exists custo_unitario numeric;

create index if not exists movimentacoes_estoque_motivo_idx
  on public.movimentacoes_estoque (motivo);
