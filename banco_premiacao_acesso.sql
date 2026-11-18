-- ============================================================
-- CENTRAL RODRIAÇO — Premiação (RH): acesso TRAVADO, igual ao Controle de Empréstimos
--
-- Rodar UMA vez, no SQL Editor do projeto Supabase "Rodriaço"
-- (vgcwzfeucfkaawwwhvjo), DEPOIS do banco_premiacao.sql.
-- Pode rodar de novo sem quebrar nada (não apaga dados).
--
-- O que faz:
--   1. cria public.premiacao_acesso: a lista de e-mails que podem receber a
--      permissão da Premiação. Só se mexe pelo SQL Editor; nenhum e-mail fica
--      escrito no site (que é público);
--   2. troca premiacao_pode(): passa a valer só para o administrador e para a
--      conta que está NESSA lista E tem a Premiação marcada em Contas > Permissões;
--   3. cria premiacao_liberaveis(), que a tela Contas (só administrador) usa para
--      saber em quem a caixinha destrava (nas outras contas ela fica "travada");
--   4. cria premiacao_eu(), que a Central usa para saber se o login atual pode
--      abrir o módulo;
--   5. para ninguém perder o acesso que já tem: coloca na lista as contas que
--      JÁ têm a Premiação marcada hoje (se não houver nenhuma, a lista fica vazia).
--
-- Depois de rodar, para liberar (ou tirar) alguém, e conferir a lista:
--
--   insert into public.premiacao_acesso (email) values ('pessoa@empresa.com.br')
--     on conflict do nothing;
--   delete from public.premiacao_acesso where email = 'pessoa@empresa.com.br';
--   select email from public.premiacao_acesso order by 1;
--
-- e então marcar RH > Premiação em Contas > Permissões para essa conta.
-- ============================================================

do $$
begin
  if to_regprocedure('public.premiacao_pode()') is null then
    raise exception 'Rode antes o banco_premiacao.sql (falta public.premiacao_pode).';
  end if;
  if to_regprocedure('public.eh_admin()') is null then
    raise exception 'Rode antes o banco_acessos.sql (falta public.eh_admin).';
  end if;
end $$;


-- ------------------------------------------------------------
-- 1. LISTA DE AUTORIZADOS (ninguém lê direto; só as funções abaixo)
-- ------------------------------------------------------------
create table if not exists public.premiacao_acesso (
  email text primary key
);
alter table public.premiacao_acesso enable row level security;
revoke all on public.premiacao_acesso from anon, authenticated;


-- ------------------------------------------------------------
-- 2. QUEM PODE: administrador, ou conta da lista com a Premiação marcada
--    (as chaves de Contas continuam 'premiacao' ou 'premiacao.subarea')
-- ------------------------------------------------------------
create or replace function public.premiacao_pode()
returns boolean language plpgsql stable security definer set search_path = public as $fn$
declare p public.perfis;
begin
  select * into p from public.perfis where id = auth.uid();
  if not found or p.status <> 'ativo' then return false; end if;
  if p.papel = 'admin' then return true; end if;
  if not exists (select 1 from public.premiacao_acesso x where lower(x.email) = lower(p.email)) then return false; end if;
  return exists (
    select 1
      from public.acessos_erp a, lateral jsonb_each_text(a.modulos) m(chave, nivel)
     where a.user_id = p.id
       and (m.chave = 'premiacao' or m.chave like 'premiacao.%')
       and m.nivel in ('ver', 'editar')
  );
end; $fn$;

-- a tela Contas (só administrador) usa isto para saber em quem a caixinha destrava
create or replace function public.premiacao_liberaveis()
returns text[] language plpgsql stable security definer set search_path = public as $fn$
begin
  if not public.eh_admin() then return '{}'::text[]; end if;
  return array(select lower(email) from public.premiacao_acesso order by 1);
end; $fn$;

-- a Central usa isto para saber se este login pode abrir a Premiação (mesma regra de premiacao_pode)
create or replace function public.premiacao_eu()
returns boolean language sql stable security definer set search_path = public as $fn$
  select public.premiacao_pode();
$fn$;

revoke all on function public.premiacao_pode() from public, anon;
revoke all on function public.premiacao_liberaveis() from public, anon;
revoke all on function public.premiacao_eu() from public, anon;
grant execute on function public.premiacao_pode() to authenticated;
grant execute on function public.premiacao_liberaveis() to authenticated;
grant execute on function public.premiacao_eu() to authenticated;


-- ------------------------------------------------------------
-- 3. MANTER QUEM JÁ TEM ACESSO HOJE
--    (contas ativas que já têm 'premiacao' ou 'premiacao.*' marcado em Contas)
-- ------------------------------------------------------------
insert into public.premiacao_acesso (email)
select distinct lower(p.email)
  from public.perfis p
  join public.acessos_erp a on a.user_id = p.id,
  lateral jsonb_each_text(a.modulos) m(chave, nivel)
 where p.status = 'ativo'
   and p.papel <> 'admin'
   and p.email is not null
   and (m.chave = 'premiacao' or m.chave like 'premiacao.%')
   and m.nivel in ('ver', 'editar')
on conflict do nothing;

-- conferência: quem está autorizado agora
--   select email from public.premiacao_acesso order by 1;
