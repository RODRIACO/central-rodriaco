-- ============================================================
-- CONTROLE DE FERRAMENTAS — só o administrador altera
--
-- Rodar UMA vez, no SQL Editor do projeto Supabase "Rodriaço"
-- (vgcwzfeucfkaawwwhvjo). Pode rodar de novo sem quebrar nada.
-- Pré-requisito: o banco.sql do Controle de Ferramentas já rodado.
--
-- Regra: quem não é administrador só LÊ. Cadastro, edição, troca,
-- reativação e qualquer movimentação (entrega, devolução, conserto,
-- perda, sucata) passam a exigir administrador.
--
-- Vale para o app dentro da Central e também para o app antigo do
-- Cloudflare: os dois falam com o mesmo banco. No app antigo, quem
-- não for administrador vai ver o erro "Somente o administrador
-- altera as ferramentas" ao tentar gravar.
--
-- Como funciona: um gatilho em ferramentas e ferramentas_mov barra
-- qualquer gravação de conta que não seja administradora — inclusive
-- as feitas pelas funções ferr_mover(), ferr_trocar() e
-- ferr_reativar(), que rodam com poderes de dono. Gravações sem
-- usuário logado (SQL Editor, carga de dados) continuam liberadas.
-- ============================================================

do $$
begin
  if to_regclass('public.ferramentas') is null
     or to_regclass('public.ferramentas_mov') is null
     or to_regproc('public.eh_admin') is null then
    raise exception 'Rode antes o banco.sql do Controle de Ferramentas.';
  end if;
end $$;

-- 1. políticas de escrita direta na tabela: só administrador
drop policy if exists ferr_inserir on public.ferramentas;
drop policy if exists ferr_alterar on public.ferramentas;
create policy ferr_inserir on public.ferramentas for insert to authenticated
  with check (public.eh_admin());
create policy ferr_alterar on public.ferramentas for update to authenticated
  using (public.eh_admin()) with check (public.eh_admin());

-- 2. gatilho: barra também as funções que rodam com poderes de dono
create or replace function public.ferr_so_admin()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if auth.uid() is not null and not public.eh_admin() then
    raise exception 'Somente o administrador altera as ferramentas.';
  end if;
  if TG_OP = 'DELETE' then return old; end if;
  return new;
end; $fn$;

drop trigger if exists ferr_so_admin_trg on public.ferramentas;
create trigger ferr_so_admin_trg
before insert or update or delete on public.ferramentas
for each row execute function public.ferr_so_admin();

drop trigger if exists ferrmov_so_admin_trg on public.ferramentas_mov;
create trigger ferrmov_so_admin_trg
before insert or update or delete on public.ferramentas_mov
for each row execute function public.ferr_so_admin();

-- ------------------------------------------------------------
-- CONFERÊNCIA (opcional) — rode separado:
--
--   select tgname, tgrelid::regclass from pg_trigger
--    where tgname in ('ferr_so_admin_trg', 'ferrmov_so_admin_trg');
--     -> duas linhas
--
--   select policyname, cmd from pg_policies
--    where tablename = 'ferramentas' order by policyname;
--     -> ferr_inserir (INSERT) e ferr_alterar (UPDATE) agora exigem eh_admin()
-- ------------------------------------------------------------
