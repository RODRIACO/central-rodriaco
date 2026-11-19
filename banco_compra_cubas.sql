-- ============================================================
-- CENTRAL RODRIAÇO — Apps de suporte > Compra de Cubas
--
-- Rodar UMA vez, no SQL Editor do projeto Supabase "Rodriaço"
-- (vgcwzfeucfkaawwwhvjo), DEPOIS do banco_acessos.sql.
-- Pode rodar de novo sem quebrar nada.
--
-- O que faz: a leitura dos arquivos do robô (bucket dados-cosmos:
-- "DADOS COSMOS.csv" e "OPs concluidas.csv") passa a valer também
-- para quem tem a subárea "apps.compra_cubas" (ou o módulo Apps de
-- suporte inteiro), além da Logística > Análise CSV e da
-- Comercial > Análise de Pedidos.
-- O robô usa a service key e continua gravando normalmente.
-- A tela Compra de Cubas só LÊ esses arquivos: não grava nada no banco.
--
-- Atenção: a regra do Storage vale para o bucket inteiro, então quem
-- recebe esta permissão também consegue ler o "Relatorio de Pedidos.csv"
-- (que não tem valores em R$), igual a quem tem a Análise CSV.
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
              or public.tem_acesso('comercial.analisePedidos', 'ver')
              or public.tem_acesso('apps.compra_cubas', 'ver')));


-- ------------------------------------------------------------
-- CONFERÊNCIA (opcional) — rode separado:
--
--   select policyname, cmd, qual from pg_policies
--    where schemaname = 'storage' and tablename = 'objects' and policyname = 'cosmos ler';
--     -> uma linha, cmd = SELECT, qual citando logistica.csv,
--        comercial.analisePedidos e apps.compra_cubas
-- ------------------------------------------------------------
