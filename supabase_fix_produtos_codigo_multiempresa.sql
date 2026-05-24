-- Corrige conflito 409 ao cadastrar produtos em empresas diferentes.
-- Remove unicidade antiga somente em produtos.codigo e garante unicidade por empresa.

drop index if exists public.produtos_codigo_unique;

do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'produtos'
      and c.contype = 'u'
      and (
        select array_agg(a.attname::text order by a.attnum)
        from unnest(c.conkey) as key(attnum)
        join pg_attribute a
          on a.attrelid = c.conrelid
         and a.attnum = key.attnum
      ) = array['codigo']
  loop
    execute format(
      'alter table public.produtos drop constraint if exists %I',
      constraint_name
    );
  end loop;
end $$;

create unique index if not exists produtos_empresa_codigo_unique
  on public.produtos (empresa_id, codigo);
