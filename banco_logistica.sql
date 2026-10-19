-- ============================================================
-- LOGÍSTICA > ANÁLISE CSV — permissão de leitura do arquivo do robô
--
-- Rodar UMA vez, no SQL Editor do projeto Supabase "Rodriaço"
-- (vgcwzfeucfkaawwwhvjo).
--
-- Pré-requisito: o banco.sql do Estoque Livre já rodado
-- (é ele que cria a tabela public.perfis e a função public.ativo()).
--
-- O que faz:
--   1. deixa o bucket "dados-cosmos" PRIVADO;
--   2. libera a LEITURA do bucket só para quem está logado E com perfil ativo.
--
-- O robô (robo_coletor.py) usa a service key e continua gravando
-- normalmente — a service key ignora essas regras.
-- Ninguém ganha permissão de gravar ou apagar pelo app.
-- ============================================================

do $$
begin
  if to_regprocedure('public.ativo()') is null then
    raise exception 'Rode antes o banco.sql do Estoque Livre (falta a função public.ativo()).';
  end if;
end $$;

-- 1) bucket privado (cria se ainda não existir)
insert into storage.buckets (id, name, public)
values ('dados-cosmos', 'dados-cosmos', false)
on conflict (id) do update set public = false;

-- 2) leitura só para conta logada e ativa
drop policy if exists "cosmos ler" on storage.objects;
create policy "cosmos ler" on storage.objects
  for select to authenticated
  using (bucket_id = 'dados-cosmos' and public.ativo());

-- ------------------------------------------------------------
-- CONFERÊNCIA (opcional) — rode separado e confira:
--
--   select id, public from storage.buckets where id = 'dados-cosmos';
--     -> public tem que ser false
--
--   select policyname, cmd from pg_policies
--    where schemaname = 'storage' and tablename = 'objects' and policyname = 'cosmos ler';
--     -> uma linha, cmd = SELECT
--
-- Sem login, este endereço tem que responder erro (nunca o CSV):
--   https://vgcwzfeucfkaawwwhvjo.supabase.co/storage/v1/object/public/dados-cosmos/DADOS%20COSMOS.csv
-- ------------------------------------------------------------
