-- ============================================================
-- CENTRAL RODRIAÇO — Premiação (assiduidade / pontualidade)
--
-- Rodar UMA vez, no SQL Editor do projeto Supabase "Rodriaço"
-- (vgcwzfeucfkaawwwhvjo), DEPOIS do banco_acessos.sql.
-- Pode rodar de novo sem quebrar nada (não apaga dados).
--
-- O que faz:
--   1. cria public.premiacao_meses (um registro por mês: funcionários, ponto,
--      notas dos setores, valores e versão da regra), public.premiacao_apelidos
--      (nomes que o ponto eletrônico escreve diferente do cadastro) e
--      public.premiacao_log (mudanças de regra/dados e o que o app registra);
--   2. cria premiacao_pode(): vale para o administrador e para quem tiver
--      qualquer subárea do módulo "Premiação" marcada em Contas > Permissões;
--   3. liga o RLS: sem a permissão, o banco não devolve NADA
--      (os valores e os nomes ficam só aqui, nunca no index.html público).
--
-- Quem acessa: o administrador libera em Contas > Permissões > Premiação
-- (hoje: Piccolo e Elis, além do administrador).
-- NÃO guarda CPF.
-- ============================================================

do $$
begin
  if to_regprocedure('public.tem_acesso(text, text)') is null then
    raise exception 'Rode antes o banco_acessos.sql (falta public.tem_acesso).';
  end if;
end $$;


-- ------------------------------------------------------------
-- 1. QUEM PODE
--    As chaves de Contas são 'premiacao' ou 'premiacao.subarea'.
--    Qualquer uma delas libera os dados do módulo.
-- ------------------------------------------------------------
create or replace function public.premiacao_pode()
returns boolean language plpgsql stable security definer set search_path = public as $fn$
declare p public.perfis;
begin
  select * into p from public.perfis where id = auth.uid();
  if not found or p.status <> 'ativo' then return false; end if;
  if p.papel = 'admin' then return true; end if;
  return exists (
    select 1
      from public.acessos_erp a, lateral jsonb_each_text(a.modulos) m(chave, nivel)
     where a.user_id = p.id
       and (m.chave = 'premiacao' or m.chave like 'premiacao.%')
       and m.nivel in ('ver', 'editar')
  );
end; $fn$;

grant execute on function public.premiacao_pode() to authenticated;


-- ------------------------------------------------------------
-- 2. TABELAS
--    premiacao_meses.itens   = [{nome, setor, cc, lider, afastado, ferias,
--                                ponto:{atraso,falta,atestado}|null, snap:{...}}]
--                              (tempos em segundos; snap = valores gravados ao fechar)
--    premiacao_meses.setores = {"Corte":{"ap":[4,3,..],"ci":[..],"co":[..]}, ...}
--                              (4 = ótimo, 3 = bom, 2 = regular, 1 = ruim, 0 = sem nota)
--    premiacao_meses.conf    = {"ponto":true,"setores":true} (o que já foi conferido)
-- ------------------------------------------------------------
create table if not exists public.premiacao_meses (
  mes            date primary key,                        -- sempre o dia 1 do mês da premiação
  periodo        text not null default '',                -- texto do ponto, ex.: '15/09 - 14/10'
  regra          integer not null default 2,              -- versão da regra de pontuação do mês (1 = piloto de 08/2025; 2 = desde 09/2025)
  itens          jsonb not null default '[]'::jsonb,
  setores        jsonb not null default '{}'::jsonb,
  conf           jsonb not null default '{}'::jsonb,
  fechado        boolean not null default false,
  atualizado_em  timestamptz not null default now(),
  atualizado_por text not null default ''
);

alter table public.premiacao_meses add column if not exists regra integer not null default 2;

create table if not exists public.premiacao_apelidos (
  chave text primary key,                                 -- nome do ponto, em maiúsculas e sem acento
  nome  text not null                                     -- nome do funcionário no cadastro
);

-- Log: mudanças de regra, de dados, da planilha e o que o app faz (importar, fechar, reabrir...)
--   tipo   = regra | dados | cadastro | planilha | documentacao | sistema | manual
--   origem = carga (histórico carregado das planilhas) | sistema (o app registrou) | manual (alguém escreveu na tela Log)
create table if not exists public.premiacao_log (
  id        bigint generated always as identity primary key,
  em        timestamptz not null default now(),
  mes       date,                                         -- mês da premiação a que se refere (pode ser nulo)
  tipo      text not null default 'manual',
  titulo    text not null,
  descricao text not null default '',
  autor     text not null default '',
  origem    text not null default 'manual'
);
create index if not exists premiacao_log_em_idx on public.premiacao_log (em desc);

alter table public.premiacao_meses    enable row level security;
alter table public.premiacao_apelidos enable row level security;
alter table public.premiacao_log      enable row level security;

drop policy if exists prem_meses_ler    on public.premiacao_meses;
drop policy if exists prem_meses_gravar on public.premiacao_meses;
create policy prem_meses_ler    on public.premiacao_meses for select to authenticated
  using (public.premiacao_pode());
create policy prem_meses_gravar on public.premiacao_meses for all to authenticated
  using (public.premiacao_pode()) with check (public.premiacao_pode());

drop policy if exists prem_apelidos_ler    on public.premiacao_apelidos;
drop policy if exists prem_apelidos_gravar on public.premiacao_apelidos;
create policy prem_apelidos_ler    on public.premiacao_apelidos for select to authenticated
  using (public.premiacao_pode());
create policy prem_apelidos_gravar on public.premiacao_apelidos for all to authenticated
  using (public.premiacao_pode()) with check (public.premiacao_pode());

drop policy if exists prem_log_ler    on public.premiacao_log;
drop policy if exists prem_log_gravar on public.premiacao_log;
create policy prem_log_ler    on public.premiacao_log for select to authenticated
  using (public.premiacao_pode());
create policy prem_log_gravar on public.premiacao_log for all to authenticated
  using (public.premiacao_pode()) with check (public.premiacao_pode());

revoke all on public.premiacao_meses, public.premiacao_apelidos, public.premiacao_log from anon;
grant select, insert, update, delete on public.premiacao_meses, public.premiacao_apelidos, public.premiacao_log to authenticated;


-- ------------------------------------------------------------
-- CONFERÊNCIA (opcional) — rode separado:
--
--   select count(*) from public.premiacao_meses;
--     -> 0 até a carga dos meses (arquivo carga_premiacao_historico.sql,
--        que fica FORA do repositório) ou até alguém lançar o mês pelo ERP.
--
--   select policyname, tablename from pg_policies
--    where schemaname = 'public' and tablename like 'premiacao%';
--     -> 6 linhas.
-- ------------------------------------------------------------
