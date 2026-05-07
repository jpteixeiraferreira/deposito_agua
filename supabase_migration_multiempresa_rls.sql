-- Multiempresa + RLS.
-- Execute depois da migration de robustez.
--
-- Depois de executar, vincule o usuario administrador criado no Supabase Auth:
-- insert into public.usuarios_empresas (user_id, empresa_id, papel)
-- values ('COLE_AQUI_O_AUTH_USER_ID', (select id from public.empresas limit 1), 'admin');

create extension if not exists pgcrypto;

create table if not exists public.empresas (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table if not exists public.usuarios_empresas (
  user_id uuid not null references auth.users(id) on delete cascade,
  empresa_id uuid not null references public.empresas(id) on delete cascade,
  nome text,
  email text,
  ativo boolean not null default true,
  papel text not null default 'operador',
  criado_em timestamptz not null default now(),
  primary key (user_id, empresa_id)
);

create table if not exists public.admins_globais (
  user_id uuid primary key references auth.users(id) on delete cascade,
  criado_em timestamptz not null default now()
);

alter table public.usuarios_empresas
  add column if not exists nome text,
  add column if not exists email text,
  add column if not exists ativo boolean not null default true;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'usuarios_empresas_papel_check'
      and conrelid = 'public.usuarios_empresas'::regclass
  ) then
    alter table public.usuarios_empresas
      add constraint usuarios_empresas_papel_check
      check (papel in ('admin', 'gerente', 'operador', 'consulta'))
      not valid;
  end if;
end $$;

insert into public.empresas (nome)
select 'Empresa padrao'
where not exists (select 1 from public.empresas);

alter table public.clientes
  add column if not exists empresa_id uuid references public.empresas(id);

alter table public.produtos
  add column if not exists empresa_id uuid references public.empresas(id);

alter table public.vendas
  add column if not exists empresa_id uuid references public.empresas(id);

alter table public.venda_itens
  add column if not exists empresa_id uuid references public.empresas(id);

alter table public.pagamentos
  add column if not exists empresa_id uuid references public.empresas(id);

alter table public.movimentacoes_estoque
  add column if not exists empresa_id uuid references public.empresas(id);

alter table public.configuracoes_recibo
  add column if not exists empresa_id uuid references public.empresas(id);

create sequence if not exists public.configuracoes_recibo_id_seq;

select setval(
  'public.configuracoes_recibo_id_seq',
  greatest(coalesce((select max(id) from public.configuracoes_recibo), 0), 1),
  coalesce((select max(id) from public.configuracoes_recibo), 0) > 0
);

alter table public.configuracoes_recibo
  alter column id set default nextval('public.configuracoes_recibo_id_seq');

with empresa_padrao as (
  select id from public.empresas order by criado_em limit 1
)
update public.clientes
set empresa_id = (select id from empresa_padrao)
where empresa_id is null;

with empresa_padrao as (
  select id from public.empresas order by criado_em limit 1
)
update public.produtos
set empresa_id = (select id from empresa_padrao)
where empresa_id is null;

with empresa_padrao as (
  select id from public.empresas order by criado_em limit 1
)
update public.vendas
set empresa_id = (select id from empresa_padrao)
where empresa_id is null;

update public.venda_itens vi
set empresa_id = v.empresa_id
from public.vendas v
where vi.venda_id = v.id
  and vi.empresa_id is null;

update public.pagamentos p
set empresa_id = v.empresa_id
from public.vendas v
where p.venda_id = v.id
  and p.empresa_id is null;

update public.movimentacoes_estoque m
set empresa_id = p.empresa_id
from public.produtos p
where m.produto_id = p.id
  and m.empresa_id is null;

with empresa_padrao as (
  select id from public.empresas order by criado_em limit 1
)
update public.configuracoes_recibo
set empresa_id = (select id from empresa_padrao)
where empresa_id is null;

alter table public.clientes alter column empresa_id set not null;
alter table public.produtos alter column empresa_id set not null;
alter table public.vendas alter column empresa_id set not null;
alter table public.venda_itens alter column empresa_id set not null;
alter table public.pagamentos alter column empresa_id set not null;
alter table public.movimentacoes_estoque alter column empresa_id set not null;
alter table public.configuracoes_recibo alter column empresa_id set not null;

drop index if exists public.vendas_numero_unique;

create unique index if not exists vendas_empresa_numero_unique
  on public.vendas (empresa_id, numero);

create unique index if not exists produtos_empresa_codigo_unique
  on public.produtos (empresa_id, codigo);

create unique index if not exists configuracoes_recibo_empresa_unique
  on public.configuracoes_recibo (empresa_id);

create index if not exists clientes_empresa_id_idx
  on public.clientes (empresa_id);

create index if not exists produtos_empresa_id_idx
  on public.produtos (empresa_id);

create index if not exists vendas_empresa_id_idx
  on public.vendas (empresa_id);

create index if not exists venda_itens_empresa_id_idx
  on public.venda_itens (empresa_id);

create index if not exists pagamentos_empresa_id_idx
  on public.pagamentos (empresa_id);

create index if not exists movimentacoes_estoque_empresa_id_idx
  on public.movimentacoes_estoque (empresa_id);

create or replace function public.usuario_tem_empresa(empresa uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.usuarios_empresas ue
    where ue.user_id = auth.uid()
      and ue.empresa_id = empresa
  );
$$;

create or replace function public.usuario_admin_global()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admins_globais ag
    where ag.user_id = auth.uid()
  );
$$;

create or replace function public.usuario_papel_empresa(empresa uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select ue.papel
  from public.usuarios_empresas ue
  where ue.user_id = auth.uid()
    and ue.empresa_id = empresa
    and ue.ativo = true
  limit 1;
$$;

create or replace function public.usuario_admin_empresa(empresa uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.usuario_admin_global()
    or coalesce(public.usuario_papel_empresa(empresa), '') = 'admin';
$$;

alter table public.empresas enable row level security;
alter table public.admins_globais enable row level security;
alter table public.usuarios_empresas enable row level security;
alter table public.clientes enable row level security;
alter table public.produtos enable row level security;
alter table public.vendas enable row level security;
alter table public.venda_itens enable row level security;
alter table public.pagamentos enable row level security;
alter table public.movimentacoes_estoque enable row level security;
alter table public.configuracoes_recibo enable row level security;

drop policy if exists empresas_select_usuario on public.empresas;
create policy empresas_select_usuario
on public.empresas
for select
using (public.usuario_tem_empresa(id) or public.usuario_admin_global());

drop policy if exists empresas_admin_global_all on public.empresas;
create policy empresas_admin_global_all
on public.empresas
for all
using (public.usuario_admin_global())
with check (public.usuario_admin_global());

drop policy if exists admins_globais_select_self on public.admins_globais;
create policy admins_globais_select_self
on public.admins_globais
for select
using (user_id = auth.uid());

drop policy if exists usuarios_empresas_select_proprio on public.usuarios_empresas;
create policy usuarios_empresas_select_proprio
on public.usuarios_empresas
for select
using (
  user_id = auth.uid()
  or public.usuario_admin_empresa(empresa_id)
  or public.usuario_admin_global()
);

drop policy if exists clientes_empresa_all on public.clientes;
create policy clientes_empresa_all
on public.clientes
for all
using (public.usuario_tem_empresa(empresa_id))
with check (public.usuario_tem_empresa(empresa_id));

drop policy if exists produtos_empresa_all on public.produtos;
create policy produtos_empresa_all
on public.produtos
for all
using (public.usuario_tem_empresa(empresa_id))
with check (public.usuario_tem_empresa(empresa_id));

drop policy if exists vendas_empresa_all on public.vendas;
create policy vendas_empresa_all
on public.vendas
for all
using (public.usuario_tem_empresa(empresa_id))
with check (public.usuario_tem_empresa(empresa_id));

drop policy if exists venda_itens_empresa_all on public.venda_itens;
create policy venda_itens_empresa_all
on public.venda_itens
for all
using (public.usuario_tem_empresa(empresa_id))
with check (public.usuario_tem_empresa(empresa_id));

drop policy if exists pagamentos_empresa_all on public.pagamentos;
create policy pagamentos_empresa_all
on public.pagamentos
for all
using (public.usuario_tem_empresa(empresa_id))
with check (public.usuario_tem_empresa(empresa_id));

drop policy if exists movimentacoes_empresa_all on public.movimentacoes_estoque;
create policy movimentacoes_empresa_all
on public.movimentacoes_estoque
for all
using (public.usuario_tem_empresa(empresa_id))
with check (public.usuario_tem_empresa(empresa_id));

drop policy if exists configuracoes_recibo_empresa_all on public.configuracoes_recibo;
create policy configuracoes_recibo_empresa_all
on public.configuracoes_recibo
for all
using (public.usuario_tem_empresa(empresa_id))
with check (public.usuario_tem_empresa(empresa_id));
