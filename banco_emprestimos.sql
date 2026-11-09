-- ============================================================
-- CONTROLE DE EMPRÉSTIMOS — dentro da Central Rodriaço
--
-- Rodar UMA vez, no SQL Editor do projeto Supabase "Rodriaço"
-- (vgcwzfeucfkaawwwhvjo). Pode rodar de novo sem quebrar nada
-- (não apaga dados).
-- Pré-requisito: banco_acessos.sql já rodado (função tem_acesso).
--
-- Quem acessa: administrador e contas com a caixinha
-- "Apps de suporte › Controle de Empréstimos" marcada em Contas.
-- Os dados são pessoais (nome, folha, dívida): sem a permissão o banco
-- não devolve NENHUMA linha, mesmo para quem conhece o endereço.
--
-- Desenho: o app trabalha com objetos JSON. Cada funcionário, empréstimo e
-- linha do log é uma linha de tabela (coluna dados = o objeto). O log só
-- cresce: ninguém altera nem apaga.
-- ============================================================

do $$
begin
  if to_regprocedure('public.tem_acesso(text, text)') is null then
    raise exception 'Rode antes o banco_acessos.sql (falta public.tem_acesso).';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1. TABELAS
-- ------------------------------------------------------------
create table if not exists public.emp_config (
  id             text primary key,
  dados          jsonb not null default '{}'::jsonb,
  versao         integer not null default 1,
  atualizado_em  timestamptz not null default now(),
  atualizado_por text not null default ''
);
create table if not exists public.emp_funcionarios (
  id             text primary key,
  dados          jsonb not null,
  versao         integer not null default 1,
  atualizado_em  timestamptz not null default now(),
  atualizado_por text not null default ''
);
create table if not exists public.emp_emprestimos (
  id             text primary key,
  dados          jsonb not null,
  versao         integer not null default 1,
  atualizado_em  timestamptz not null default now(),
  atualizado_por text not null default ''
);
create table if not exists public.emp_log (
  id             text primary key,
  dados          jsonb not null,
  versao         integer not null default 1,
  atualizado_em  timestamptz not null default now(),
  atualizado_por text not null default ''
);

-- ------------------------------------------------------------
-- 2. CARIMBO: quem gravou, quando, e a versão (edição simultânea)
--    O app só atualiza uma linha se a versão ainda for a que ele leu.
-- ------------------------------------------------------------
create or replace function public.emp_carimbo()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare quem text;
begin
  select coalesce(nullif(nome, ''), email, '') into quem from public.perfis where id = auth.uid();
  new.atualizado_em  := now();
  new.atualizado_por := coalesce(quem, '');
  if TG_OP = 'UPDATE' then
    new.versao := old.versao + 1;
  else
    new.versao := 1;
  end if;
  return new;
end; $fn$;

drop trigger if exists emp_carimbo_trg on public.emp_config;
create trigger emp_carimbo_trg before insert or update on public.emp_config
  for each row execute function public.emp_carimbo();
drop trigger if exists emp_carimbo_trg on public.emp_funcionarios;
create trigger emp_carimbo_trg before insert or update on public.emp_funcionarios
  for each row execute function public.emp_carimbo();
drop trigger if exists emp_carimbo_trg on public.emp_emprestimos;
create trigger emp_carimbo_trg before insert or update on public.emp_emprestimos
  for each row execute function public.emp_carimbo();
drop trigger if exists emp_carimbo_trg on public.emp_log;
create trigger emp_carimbo_trg before insert or update on public.emp_log
  for each row execute function public.emp_carimbo();

-- ------------------------------------------------------------
-- 3. LOG IMUTÁVEL: nem pelo app, nem por quem tem acesso.
--    (Só o SQL Editor, que roda como dono, consegue mexer.)
-- ------------------------------------------------------------
create or replace function public.emp_log_imutavel()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if auth.uid() is not null then
    raise exception 'O log de empréstimos não pode ser alterado nem apagado.';
  end if;
  if TG_OP = 'DELETE' then return old; end if;
  return new;
end; $fn$;
drop trigger if exists emp_log_imutavel_trg on public.emp_log;
create trigger emp_log_imutavel_trg before update or delete on public.emp_log
  for each row execute function public.emp_log_imutavel();

-- ------------------------------------------------------------
-- 4. REGRAS DE ACESSO (RLS)
--    ler: tem_acesso('apps.emprestimos','ver');  gravar: 'editar'.
--    A tela Contas liga/desliga como 'editar', então quem recebe a caixinha lê e grava.
-- ------------------------------------------------------------
alter table public.emp_config       enable row level security;
alter table public.emp_funcionarios enable row level security;
alter table public.emp_emprestimos  enable row level security;
alter table public.emp_log          enable row level security;

do $$
declare t text;
begin
  foreach t in array array['emp_config', 'emp_funcionarios', 'emp_emprestimos'] loop
    execute format('drop policy if exists %I on public.%I', t || '_ler', t);
    execute format('drop policy if exists %I on public.%I', t || '_inserir', t);
    execute format('drop policy if exists %I on public.%I', t || '_alterar', t);
    execute format('drop policy if exists %I on public.%I', t || '_apagar', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.tem_acesso(%L, %L))', t || '_ler', t, 'apps.emprestimos', 'ver');
    execute format('create policy %I on public.%I for insert to authenticated with check (public.tem_acesso(%L, %L))', t || '_inserir', t, 'apps.emprestimos', 'editar');
    execute format('create policy %I on public.%I for update to authenticated using (public.tem_acesso(%L, %L)) with check (public.tem_acesso(%L, %L))', t || '_alterar', t, 'apps.emprestimos', 'editar', 'apps.emprestimos', 'editar');
    execute format('create policy %I on public.%I for delete to authenticated using (public.tem_acesso(%L, %L))', t || '_apagar', t, 'apps.emprestimos', 'editar');
  end loop;
end $$;

drop policy if exists emp_log_ler on public.emp_log;
drop policy if exists emp_log_inserir on public.emp_log;
create policy emp_log_ler on public.emp_log for select to authenticated
  using (public.tem_acesso('apps.emprestimos', 'ver'));
create policy emp_log_inserir on public.emp_log for insert to authenticated
  with check (public.tem_acesso('apps.emprestimos', 'editar'));

-- sem sessão (anon) não chega nada; o login já faz o resto
revoke all on public.emp_config, public.emp_funcionarios, public.emp_emprestimos, public.emp_log from anon;
grant select, insert, update, delete on public.emp_config, public.emp_funcionarios, public.emp_emprestimos to authenticated;
grant select, insert on public.emp_log to authenticated;
-- as funções de carimbo/log rodam como dono; o app não as chama
revoke all on function public.emp_carimbo() from public, anon, authenticated;
revoke all on function public.emp_log_imutavel() from public, anon, authenticated;

-- ------------------------------------------------------------
-- CONFERÊNCIA (opcional) — rode separado:
--
--   select tablename, rowsecurity from pg_tables where tablename like 'emp\_%' order by 1;
--     -> quatro linhas, rowsecurity = true
--
--   select tablename, policyname, cmd from pg_policies where tablename like 'emp\_%' order by 1, 2;
--     -> ler/inserir/alterar/apagar nas 3 primeiras, ler/inserir no log
-- ------------------------------------------------------------
