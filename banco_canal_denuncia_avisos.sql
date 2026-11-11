-- ============================================================
--  CANAL DE DENÚNCIA — AVISOS POR E-MAIL (parte 2 do banco)
--  Rode DEPOIS do banco_canal_denuncia.sql, no SQL Editor do Supabase.
--  Pode rodar de novo sem problema.
--
--  O que faz: deixa o robô de avisos (repositório privado ROBO-COSMOS)
--  perguntar "tem denúncia nova ou resposta sem aviso?" e depois
--  marcar como avisado. O robô só recebe CONTAGENS e os e-mails de quem
--  está em denuncia_acesso. Nunca recebe texto, tipo, protocolo ou número.
--
--  Quem pode chamar: SOMENTE a chave service_role (o segredo do robô).
--  Nem o app, nem o admin da Central, nem o visitante alcançam estas funções.
-- ============================================================

-- 1. Marca de "já avisei" nas denúncias e nas mensagens
do $$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'denuncias' and column_name = 'aviso_em') then
    alter table public.denuncias add column aviso_em timestamptz;
    update public.denuncias set aviso_em = now();      -- o que já existe não gera e-mail
  end if;
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'denuncia_msgs' and column_name = 'aviso_em') then
    alter table public.denuncia_msgs add column aviso_em timestamptz;
    update public.denuncia_msgs set aviso_em = now();
  end if;
end $$;

create index if not exists denuncias_aviso_idx  on public.denuncias(criado_em)  where aviso_em is null;
create index if not exists denuncia_msgs_aviso_idx on public.denuncia_msgs(em) where aviso_em is null;

-- 2. O que está pendente, por destinatário (só contagens)
--    RH não recebe aviso do que envolve o RH; Direção recebe de tudo.
create or replace function public.denuncia_avisos_pendentes()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_corte timestamptz := now();
  v_dest  jsonb;
  v_total bigint;
begin
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_dest
    from (
      select u.email as email,
             (select count(*) from public.denuncias d
               where d.aviso_em is null and d.criado_em <= v_corte
                 and (a.papel = 'direcao' or not d.envolve_rh)) as novas,
             (select count(*) from public.denuncia_msgs m
                join public.denuncias d on d.id = m.denuncia_id
               where m.autor = 'denunciante' and m.aviso_em is null and m.em <= v_corte
                 and (a.papel = 'direcao' or not d.envolve_rh)) as respostas
        from public.denuncia_acesso a
        join auth.users u on u.id = a.user_id
       where u.email is not null
    ) x
   where x.novas > 0 or x.respostas > 0;

  select (select count(*) from public.denuncias    where aviso_em is null and criado_em <= v_corte)
       + (select count(*) from public.denuncia_msgs where aviso_em is null and autor = 'denunciante' and em <= v_corte)
    into v_total;

  return jsonb_build_object('corte', v_corte, 'pendentes', v_total, 'destinatarios', v_dest);
end $$;

-- 3. Depois de enviar, o robô marca tudo até o "corte" como avisado
create or replace function public.denuncia_avisos_baixar(p_corte timestamptz)
returns void language sql security definer set search_path = public as $$
  update public.denuncias    set aviso_em = now() where aviso_em is null and criado_em <= p_corte;
  update public.denuncia_msgs set aviso_em = now() where aviso_em is null and em        <= p_corte;
$$;

-- 4. Só a chave service_role executa (revoga também de anon e authenticated,
--    porque o Supabase concede a eles por padrão)
revoke all on function public.denuncia_avisos_pendentes()          from public, anon, authenticated;
revoke all on function public.denuncia_avisos_baixar(timestamptz)  from public, anon, authenticated;
grant execute on function public.denuncia_avisos_pendentes()         to service_role;
grant execute on function public.denuncia_avisos_baixar(timestamptz) to service_role;

-- 5. Conferência (deve devolver 2 linhas, ambas com anon = false e authenticated = false)
select p.proname,
       has_function_privilege('anon',          p.oid, 'execute') as anon,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated,
       has_function_privilege('service_role',  p.oid, 'execute') as service_role
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('denuncia_avisos_pendentes', 'denuncia_avisos_baixar');
