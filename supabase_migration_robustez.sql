-- Execute no SQL Editor do Supabase antes de usar os novos recursos.
-- A migracao preserva dados existentes e adiciona campos para numero sequencial,
-- status/cancelamento de venda e auditoria de movimentacoes.

alter table public.clientes
  add column if not exists ativo boolean not null default true;

alter table public.produtos
  add column if not exists ativo boolean not null default true,
  add column if not exists preco_custo numeric not null default 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'produtos_preco_venda_maior_zero_check'
      and conrelid = 'public.produtos'::regclass
  ) then
    alter table public.produtos
      add constraint produtos_preco_venda_maior_zero_check
      check (preco_venda > 0)
      not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'produtos_custo_menor_ou_igual_venda_check'
      and conrelid = 'public.produtos'::regclass
  ) then
    alter table public.produtos
      add constraint produtos_custo_menor_ou_igual_venda_check
      check (preco_custo <= preco_venda)
      not valid;
  end if;
end $$;

alter table public.vendas
  add column if not exists numero integer,
  add column if not exists status text not null default 'finalizada',
  add column if not exists cancelada_em timestamptz,
  add column if not exists motivo_cancelamento text;

update public.vendas
set status = 'finalizada'
where status is null;

with numeradas as (
  select
    id,
    row_number() over (order by data_venda, id)::integer as novo_numero
  from public.vendas
  where numero is null
)
update public.vendas v
set numero = n.novo_numero
from numeradas n
where v.id = n.id;

create unique index if not exists vendas_numero_unique
  on public.vendas (numero);

create sequence if not exists public.vendas_numero_seq;

select setval(
  'public.vendas_numero_seq',
  greatest(coalesce((select max(numero) from public.vendas), 0), 1),
  coalesce((select max(numero) from public.vendas), 0) > 0
);

alter table public.vendas
  alter column numero set default nextval('public.vendas_numero_seq');

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'vendas_status_check'
      and conrelid = 'public.vendas'::regclass
  ) then
    alter table public.vendas
      add constraint vendas_status_check
      check (status in ('finalizada', 'cancelada'))
      not valid;
  end if;
end $$;

alter table public.vendas validate constraint vendas_status_check;

alter table public.movimentacoes_estoque
  add column if not exists criado_em timestamptz not null default now(),
  add column if not exists observacao text;

create index if not exists vendas_status_idx
  on public.vendas (status);

create index if not exists vendas_cliente_id_idx
  on public.vendas (cliente_id);

create index if not exists venda_itens_produto_id_idx
  on public.venda_itens (produto_id);

create index if not exists movimentacoes_estoque_produto_id_idx
  on public.movimentacoes_estoque (produto_id);
