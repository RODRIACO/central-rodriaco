-- ============================================================
-- CENTRAL RODRIAÇO — Comercial > Análise de Pedidos
--
-- Rodar UMA vez, no SQL Editor do projeto Supabase "Rodriaço"
-- (vgcwzfeucfkaawwwhvjo), DEPOIS do banco_acessos.sql.
-- Pode rodar de novo sem quebrar nada.
--
-- O que faz: a leitura dos arquivos do robô (bucket dados-cosmos:
-- "DADOS COSMOS.csv" e "Relatorio de Pedidos.csv") passa a valer
-- também para quem tem a subárea "comercial.analisePedidos"
-- (ou o módulo Comercial inteiro), além da Logística > Análise CSV.
-- O robô usa a service key e continua gravando normalmente.
-- ============================================================

do $$
begin
  if to_regprocedure('public.tem_acesso(text, text)') is null then
    raise exception 'Rode antes o banco_acessos.sql (falta public.tem_acesso).';
  end if;
end $$;

drop policy if exists "cosmos ler" on storage.objects;
create policy "cosmos ler" on storage.objects
  for select to authenticated
  using (bucket_id = 'dados-cosmos'
         and (public.tem_acesso('logistica.csv', 'ver')
              or public.tem_acesso('comercial.analisePedidos', 'ver')));


-- ------------------------------------------------------------
-- CONFERÊNCIA (opcional) — rode separado:
--
--   select policyname, cmd, qual from pg_policies
--    where schemaname = 'storage' and tablename = 'objects' and policyname = 'cosmos ler';
--     -> uma linha, cmd = SELECT, qual citando logistica.csv e comercial.analisePedidos
-- ------------------------------------------------------------
