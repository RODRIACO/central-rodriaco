-- ============================================================
-- CENTRAL RODRIAÇO — contas e acessos por módulo
--
-- Rodar UMA vez, no SQL Editor do projeto Supabase "Rodriaço"
-- (vgcwzfeucfkaawwwhvjo). Pode rodar de novo sem quebrar nada.
--
-- Pré-requisito: o banco.sql do Estoque Livre já rodado
-- (é ele que cria public.perfis, ativo(), eh_admin() e o gatilho
-- que cria o perfil quando uma conta nasce).
--
-- O que faz:
--   1. cria public.acessos_erp (quais módulos cada conta pode usar);
--   2. cria meus_acessos() e tem_acesso() — o ERP e as regras do banco usam;
--   3. só administrador lê/grava a tabela de acessos de todo mundo;
--   4. a leitura do CSV da Logística passa a exigir o módulo "logistica"
--      (substitui o banco_logistica.sql — não precisa rodar os dois);
--   5. garante pcp1@mrinox.com.br como administrador ativo.
--
-- NÃO mexe em perfis.papel nem nas regras do Estoque Livre e do
-- Controle de Ferramentas: elas seguem funcionando como estão.
-- Conta nova nasce SEM nenhum módulo até um administrador liberar.
-- ============================================================

do $$
begin
  if to_regclass('public.perfis') is null
     or to_regprocedure('public.eh_admin()') is null
     or to_regprocedure('public.ativo()') is null then
    raise exception 'Rode antes o banco.sql do Estoque Livre (faltam public.perfis, ativo() e eh_admin()).';
  end if;
end $$;


-- ------------------------------------------------------------
-- 1. ACESSOS POR MÓDULO
--    modulos = {"logistica":"editar","pcp":"editar"}
--    Hoje a tela liga/desliga ("editar" = liberado). O banco já
--    aceita "ver" para quando cada app passar a usar níveis.
-- ------------------------------------------------------------
create table if not exists public.acessos_erp (
  user_id       uuid primary key references public.perfis(id) on delete cascade,
  modulos       jsonb not null default '{}'::jsonb,
  atualizado_em timestamptz not null default now(),
  atualizado_por text not null default ''
);

alter table public.acessos_erp enable row level security;

drop policy if exists acessos_ler_proprio on public.acessos_erp;
drop policy if exists acessos_admin       on public.acessos_erp;
create policy acessos_ler_proprio on public.acessos_erp for select to authenticated
  using (user_id = auth.uid());
create policy acessos_admin on public.acessos_erp for all to authenticated
  using (public.eh_admin()) with check (public.eh_admin());


-- ------------------------------------------------------------
-- 2. FUNÇÕES
--    meus_acessos(): o que a conta logada enxerga no ERP.
--    tem_acesso(modulo, nivel): usada pelas regras do banco.
--    Administrador (perfis.papel = 'admin' e ativo) tem tudo.
-- ------------------------------------------------------------
create or replace function public.meus_acessos()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare p public.perfis; m jsonb;
begin
  select * into p from public.perfis where id = auth.uid();
  if not found then
    return jsonb_build_object('status', 'sem_perfil', 'admin', false, 'modulos', '{}'::jsonb);
  end if;
  if p.status <> 'ativo' then
    return jsonb_build_object('status', p.status, 'admin', false, 'modulos', '{}'::jsonb);
  end if;
  select coalesce(a.modulos, '{}'::jsonb) into m from public.acessos_erp a where a.user_id = p.id;
  return jsonb_build_object(
    'status', p.status,
    'admin',  (p.papel = 'admin'),
    'modulos', coalesce(m, '{}'::jsonb)
  );
end; $fn$;

create or replace function public.tem_acesso(p_modulo text, p_nivel text default 'ver')
returns boolean language plpgsql stable security definer set search_path = public as $fn$
declare p public.perfis; nivel text;
begin
  select * into p from public.perfis where id = auth.uid();
  if not found or p.status <> 'ativo' then return false; end if;
  if p.papel = 'admin' then return true; end if;
  select a.modulos ->> p_modulo into nivel from public.acessos_erp a where a.user_id = p.id;
  if nivel is null then return false; end if;
  if p_nivel = 'ver' then return nivel in ('ver', 'editar'); end if;
  return nivel = 'editar';
end; $fn$;

grant execute on function public.meus_acessos()            to authenticated;
grant execute on function public.tem_acesso(text, text)    to authenticated;


-- ------------------------------------------------------------
-- 3. LOGÍSTICA > ANÁLISE CSV
--    Bucket privado; leitura só para quem tem o módulo "logistica".
--    O robô usa a service key e continua gravando normalmente.
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('dados-cosmos', 'dados-cosmos', false)
on conflict (id) do update set public = false;

drop policy if exists "cosmos ler" on storage.objects;
create policy "cosmos ler" on storage.objects
  for select to authenticated
  using (bucket_id = 'dados-cosmos' and public.tem_acesso('logistica', 'ver'));


-- ------------------------------------------------------------
-- 4. ADMINISTRADOR
--    Pelo SQL Editor não existe auth.uid(), então o gatilho
--    que protege o papel é desligado só durante este bloco.
-- ------------------------------------------------------------
do $$
declare u record;
begin
  select id, email, raw_user_meta_data into u
    from auth.users where lower(email) = 'pcp1@mrinox.com.br';
  if not found then
    raise notice 'A conta pcp1@mrinox.com.br ainda não existe em Authentication > Users. Crie e rode este bloco de novo.';
    return;
  end if;

  alter table public.perfis disable trigger perfis_protege_papel;
  insert into public.perfis (id, email, nome, papel, status)
  values (u.id, lower(u.email),
          coalesce(nullif(u.raw_user_meta_data ->> 'nome', ''), split_part(u.email, '@', 1)),
          'admin', 'ativo')
  on conflict (id) do update set papel = 'admin', status = 'ativo';
  alter table public.perfis enable trigger perfis_protege_papel;
end $$;


-- ------------------------------------------------------------
-- CONFERÊNCIA (opcional) — rode separado:
--
--   select email, papel, status from public.perfis order by email;
--     -> pcp1@mrinox.com.br com papel admin e status ativo
--
--   select policyname, cmd from pg_policies
--    where schemaname = 'storage' and tablename = 'objects' and policyname = 'cosmos ler';
--     -> uma linha, cmd = SELECT
-- ------------------------------------------------------------
