-- Adiciona suporte a descontos em vendas e itens de venda.
-- Mantem total/subtotal existentes como valores liquidos para preservar relatorios antigos.

alter table public.vendas
  add column if not exists subtotal numeric(12, 2),
  add column if not exists desconto_tipo text not null default 'valor',
  add column if not exists desconto_valor numeric(12, 2) not null default 0,
  add column if not exists desconto_total numeric(12, 2) not null default 0;

update public.vendas
set subtotal = coalesce(subtotal, total + coalesce(desconto_total, 0))
where subtotal is null;

alter table public.vendas
  alter column subtotal set not null;

alter table public.venda_itens
  add column if not exists desconto_tipo text not null default 'valor',
  add column if not exists desconto_valor numeric(12, 2) not null default 0,
  add column if not exists desconto_total numeric(12, 2) not null default 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'vendas_desconto_tipo_check'
      and conrelid = 'public.vendas'::regclass
  ) then
    alter table public.vendas
      add constraint vendas_desconto_tipo_check
      check (desconto_tipo in ('valor', 'percentual'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'vendas_desconto_valores_check'
      and conrelid = 'public.vendas'::regclass
  ) then
    alter table public.vendas
      add constraint vendas_desconto_valores_check
      check (
        subtotal >= 0
        and total >= 0
        and desconto_valor >= 0
        and desconto_total >= 0
        and desconto_total <= subtotal
        and (desconto_tipo <> 'percentual' or desconto_valor <= 100)
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'venda_itens_desconto_tipo_check'
      and conrelid = 'public.venda_itens'::regclass
  ) then
    alter table public.venda_itens
      add constraint venda_itens_desconto_tipo_check
      check (desconto_tipo in ('valor', 'percentual'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'venda_itens_desconto_valores_check'
      and conrelid = 'public.venda_itens'::regclass
  ) then
    alter table public.venda_itens
      add constraint venda_itens_desconto_valores_check
      check (
        quantidade >= 0
        and preco_unitario >= 0
        and subtotal >= 0
        and desconto_valor >= 0
        and desconto_total >= 0
        and desconto_total <= (quantidade * preco_unitario)
        and (desconto_tipo <> 'percentual' or desconto_valor <= 100)
      );
  end if;
end $$;
