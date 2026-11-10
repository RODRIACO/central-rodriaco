-- ============================================================
--  CANAL DE DENÚNCIA — RODRIAÇO
--  Roda no MESMO projeto Supabase dos outros apps, mas NÃO
--  reaproveita os perfis de lá: quem é admin do Estoque ou das
--  Ferramentas não enxerga denúncia nenhuma. O acesso é dado,
--  pessoa por pessoa, na tabela denuncia_acesso (ver acessos.sql).
--
--  Rode UMA VEZ, inteiro, no SQL Editor. Pode rodar de novo sem
--  quebrar nada (é idempotente).
-- ============================================================


-- ------------------------------------------------------------
-- 1. QUEM PODE LER DENÚNCIAS
--    'rh'      -> vê tudo, MENOS o que envolve o próprio RH
--    'direcao' -> vê tudo
--    Ninguém grava aqui pelo app: só pelo SQL Editor.
-- ------------------------------------------------------------
create table if not exists public.denuncia_acesso (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  papel     text not null check (papel in ('rh','direcao')),
  nome      text not null default '',
  criado_em timestamptz not null default now()
);
alter table public.denuncia_acesso enable row level security;
revoke all on public.denuncia_acesso from anon, authenticated;
grant select on public.denuncia_acesso to authenticated;

drop policy if exists denuncia_acesso_proprio on public.denuncia_acesso;
create policy denuncia_acesso_proprio on public.denuncia_acesso
  for select to authenticated using (user_id = auth.uid());

create or replace function public.denuncia_papel()
returns text language sql stable security definer set search_path = public as $$
  select papel from public.denuncia_acesso where user_id = auth.uid()
$$;

create or replace function public.denuncia_pode_ver(p_envolve_rh boolean)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select papel = 'direcao' or (papel = 'rh' and not p_envolve_rh)
       from public.denuncia_acesso where user_id = auth.uid()),
    false)
$$;


-- ------------------------------------------------------------
-- 2. DENÚNCIAS
--    Não há coluna de IP, aparelho, usuário ou localização.
--    O protocolo do denunciante NÃO é guardado: só o resumo
--    (hash) dele, que não permite descobrir o protocolo.
--    "numero" é a referência interna do RH (D-0001, D-0002...).
-- ------------------------------------------------------------
create table if not exists public.denuncias (
  id             uuid primary key default gen_random_uuid(),
  numero         bigint generated always as identity unique,
  protocolo_hash text not null unique,
  tipo           text not null check (tipo in
                 ('assedio_moral','assedio_sexual','discriminacao','violencia','conduta','seguranca','outro')),
  relato         text not null,
  local          text not null default '',
  quando         text not null default '',
  envolvidos     text not null default '',
  testemunhas    text not null default '',
  envolve_rh     boolean not null default false,
  ident_nome     text not null default '',
  ident_contato  text not null default '',
  status         text not null default 'recebida' check (status in
                 ('recebida','apuracao','conclusao','concluida','arquivada')),
  medida         text not null default '',
  pendente_rh    boolean not null default true,
  criado_em      timestamptz not null default now(),
  apuracao_em    timestamptz,
  conclusao_em   timestamptz,
  encerrada_em   timestamptz
);
create index if not exists denuncias_status_idx on public.denuncias(status);
create index if not exists denuncias_criado_idx on public.denuncias(criado_em desc);

create table if not exists public.denuncia_msgs (      -- conversa RH <-> denunciante
  id          bigint generated always as identity primary key,
  denuncia_id uuid not null references public.denuncias(id) on delete cascade,
  autor       text not null check (autor in ('denunciante','rh')),
  texto       text not null,
  em          timestamptz not null default now()
);
create index if not exists denuncia_msgs_idx on public.denuncia_msgs(denuncia_id, em);

create table if not exists public.denuncia_notas (     -- anotações internas + trilha de auditoria
  id          bigint generated always as identity primary key,
  denuncia_id uuid not null references public.denuncias(id) on delete cascade,
  texto       text not null,
  usuario     text not null default coalesce(auth.jwt() ->> 'email', ''),
  automatica  boolean not null default false,
  em          timestamptz not null default now()
);
create index if not exists denuncia_notas_idx on public.denuncia_notas(denuncia_id, em);

create table if not exists public.denuncia_anexos (
  id          bigint generated always as identity primary key,
  denuncia_id uuid not null references public.denuncias(id) on delete cascade,
  caminho     text not null unique,
  nome        text not null default '',
  tipo        text not null default '',
  tamanho     bigint not null default 0,
  em          timestamptz not null default now()
);
create index if not exists denuncia_anexos_idx on public.denuncia_anexos(denuncia_id);


-- ------------------------------------------------------------
-- 3. REGRAS DE ACESSO (RLS)
--    Visitante (anon) não lê nem grava NADA direto nas tabelas:
--    só passa pelas funções da seção 5.
--    RH/Direção leem; só alteram situação, medida e "pendente".
--    O relato original nunca pode ser editado nem apagado pelo app.
-- ------------------------------------------------------------
alter table public.denuncias       enable row level security;
alter table public.denuncia_msgs   enable row level security;
alter table public.denuncia_notas  enable row level security;
alter table public.denuncia_anexos enable row level security;

revoke all on public.denuncias, public.denuncia_msgs, public.denuncia_notas, public.denuncia_anexos
  from anon, authenticated;
grant select                                on public.denuncias       to authenticated;
grant update (status, medida, pendente_rh)  on public.denuncias       to authenticated;
grant select                                on public.denuncia_msgs   to authenticated;
grant insert (denuncia_id, autor, texto)    on public.denuncia_msgs   to authenticated;
grant select                                on public.denuncia_notas  to authenticated;
grant insert (denuncia_id, texto)           on public.denuncia_notas  to authenticated;
grant select                                on public.denuncia_anexos to authenticated;

drop policy if exists denuncias_ler on public.denuncias;
create policy denuncias_ler on public.denuncias
  for select to authenticated using (public.denuncia_pode_ver(envolve_rh));

drop policy if exists denuncias_alterar on public.denuncias;
create policy denuncias_alterar on public.denuncias
  for update to authenticated
  using (public.denuncia_pode_ver(envolve_rh))
  with check (public.denuncia_pode_ver(envolve_rh));

create or replace function public.denuncia_visivel(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.denuncias d
                  where d.id = p_id and public.denuncia_pode_ver(d.envolve_rh))
$$;

drop policy if exists denuncia_msgs_ler on public.denuncia_msgs;
create policy denuncia_msgs_ler on public.denuncia_msgs
  for select to authenticated using (public.denuncia_visivel(denuncia_id));
drop policy if exists denuncia_msgs_gravar on public.denuncia_msgs;
create policy denuncia_msgs_gravar on public.denuncia_msgs
  for insert to authenticated with check (autor = 'rh' and public.denuncia_visivel(denuncia_id));

drop policy if exists denuncia_notas_ler on public.denuncia_notas;
create policy denuncia_notas_ler on public.denuncia_notas
  for select to authenticated using (public.denuncia_visivel(denuncia_id));
drop policy if exists denuncia_notas_gravar on public.denuncia_notas;
create policy denuncia_notas_gravar on public.denuncia_notas
  for insert to authenticated with check (public.denuncia_visivel(denuncia_id));

drop policy if exists denuncia_anexos_ler on public.denuncia_anexos;
create policy denuncia_anexos_ler on public.denuncia_anexos
  for select to authenticated using (public.denuncia_visivel(denuncia_id));


-- ------------------------------------------------------------
-- 4. DATAS DAS ETAPAS + TRILHA DE AUDITORIA
--    Toda mudança de situação ou de medida fica registrada com
--    quem fez e quando. Não dá para apagar pelo app.
-- ------------------------------------------------------------
create or replace function public.denuncia_ao_mudar()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  quem text := coalesce(auth.jwt() ->> 'email', '');
begin
  if new.status is distinct from old.status then
    if new.status = 'apuracao'  and new.apuracao_em  is null then new.apuracao_em  := now(); end if;
    if new.status = 'conclusao' and new.conclusao_em is null then new.conclusao_em := now(); end if;
    if new.status in ('concluida','arquivada') then new.encerrada_em := now();
    else new.encerrada_em := null; end if;
    insert into public.denuncia_notas (denuncia_id, texto, usuario, automatica)
    values (new.id, 'Situação alterada: ' || old.status || ' → ' || new.status, quem, true);
  end if;
  if new.medida is distinct from old.medida then
    insert into public.denuncia_notas (denuncia_id, texto, usuario, automatica)
    values (new.id, 'Medida/conclusão registrada ou alterada.', quem, true);
  end if;
  return new;
end $$;

drop trigger if exists denuncia_ao_mudar on public.denuncias;
create trigger denuncia_ao_mudar before update on public.denuncias
  for each row execute function public.denuncia_ao_mudar();


-- ------------------------------------------------------------
-- 5. PORTA DO DENUNCIANTE (sem login)
--    Quatro funções. Fora delas o visitante não alcança nada.
-- ------------------------------------------------------------
create or replace function public.denuncia_hash(p_protocolo text)
returns text language sql immutable as $$
  select encode(sha256(convert_to(upper(trim(p_protocolo)), 'UTF8')), 'hex')
$$;

create or replace function public.denuncia_registrar(
  p_protocolo text, p_tipo text, p_relato text,
  p_local text default '', p_quando text default '',
  p_envolvidos text default '', p_testemunhas text default '',
  p_envolve_rh boolean default false,
  p_nome text default '', p_contato text default '')
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if upper(trim(p_protocolo)) !~ '^RDA-[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$' then
    raise exception 'Protocolo inválido.';
  end if;
  if length(trim(coalesce(p_relato, ''))) < 10 then
    raise exception 'Conte o que aconteceu com um pouco mais de detalhe.';
  end if;
  insert into public.denuncias
    (protocolo_hash, tipo, relato, local, quando, envolvidos, testemunhas, envolve_rh, ident_nome, ident_contato)
  values
    (public.denuncia_hash(p_protocolo), p_tipo, left(trim(p_relato), 8000),
     left(trim(coalesce(p_local, '')), 300), left(trim(coalesce(p_quando, '')), 300),
     left(trim(coalesce(p_envolvidos, '')), 1000), left(trim(coalesce(p_testemunhas, '')), 1000),
     coalesce(p_envolve_rh, false),
     left(trim(coalesce(p_nome, '')), 200), left(trim(coalesce(p_contato, '')), 200))
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.denuncia_anexar(
  p_protocolo text, p_caminho text, p_nome text, p_tipo text, p_tamanho bigint)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  select id into v_id from public.denuncias where protocolo_hash = public.denuncia_hash(p_protocolo);
  if v_id is null then raise exception 'Protocolo não encontrado.'; end if;
  if p_caminho not like v_id::text || '/%' then raise exception 'Anexo inválido.'; end if;
  if not exists (select 1 from storage.objects where bucket_id = 'denuncias' and name = p_caminho) then
    raise exception 'Arquivo não encontrado.';
  end if;
  if (select count(*) from public.denuncia_anexos where denuncia_id = v_id) >= 5 then
    raise exception 'Limite de 5 anexos por denúncia.';
  end if;
  insert into public.denuncia_anexos (denuncia_id, caminho, nome, tipo, tamanho)
  values (v_id, p_caminho, left(coalesce(p_nome, ''), 100), left(coalesce(p_tipo, ''), 100), coalesce(p_tamanho, 0));
end $$;

create or replace function public.denuncia_consultar(p_protocolo text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'numero', d.numero, 'tipo', d.tipo, 'status', d.status, 'envolve_rh', d.envolve_rh,
    'criado_em', d.criado_em, 'encerrada_em', d.encerrada_em,
    'msgs', coalesce((select jsonb_agg(jsonb_build_object('autor', m.autor, 'texto', m.texto, 'em', m.em) order by m.em)
                        from public.denuncia_msgs m where m.denuncia_id = d.id), '[]'::jsonb))
  from public.denuncias d
  where d.protocolo_hash = public.denuncia_hash(p_protocolo)
$$;

create or replace function public.denuncia_complementar(p_protocolo text, p_texto text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  select id into v_id from public.denuncias where protocolo_hash = public.denuncia_hash(p_protocolo);
  if v_id is null then raise exception 'Protocolo não encontrado.'; end if;
  if length(trim(coalesce(p_texto, ''))) < 2 then raise exception 'Escreva a mensagem.'; end if;
  if (select count(*) from public.denuncia_msgs
       where denuncia_id = v_id and autor = 'denunciante' and em > now() - interval '1 hour') >= 20 then
    raise exception 'Muitas mensagens em pouco tempo. Tente mais tarde.';
  end if;
  insert into public.denuncia_msgs (denuncia_id, autor, texto) values (v_id, 'denunciante', left(trim(p_texto), 4000));
  update public.denuncias set pendente_rh = true where id = v_id;
end $$;

revoke all on function
  public.denuncia_registrar(text,text,text,text,text,text,text,boolean,text,text),
  public.denuncia_anexar(text,text,text,text,bigint),
  public.denuncia_consultar(text),
  public.denuncia_complementar(text,text),
  public.denuncia_papel(),
  public.denuncia_pode_ver(boolean),
  public.denuncia_visivel(uuid)
from public;

grant execute on function
  public.denuncia_registrar(text,text,text,text,text,text,text,boolean,text,text),
  public.denuncia_anexar(text,text,text,text,bigint),
  public.denuncia_consultar(text),
  public.denuncia_complementar(text,text)
to anon, authenticated;

grant execute on function
  public.denuncia_papel(), public.denuncia_pode_ver(boolean), public.denuncia_visivel(uuid)
to authenticated;


-- ------------------------------------------------------------
-- 6. ANEXOS (Storage)
--    Balde privado. O visitante só consegue ENVIAR, e só para a
--    pasta de uma denúncia criada há menos de 1 dia. Não lê,
--    não lista, não apaga. RH/Direção leem conforme a regra da
--    denúncia a que o anexo pertence.
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('denuncias', 'denuncias', false, 10485760,
        array['image/jpeg','image/png','image/webp','application/pdf',
              'audio/mpeg','audio/mp4','audio/x-m4a','audio/aac','audio/ogg','audio/webm','audio/wav','audio/x-wav','audio/3gpp','audio/amr'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.denuncia_aceita_anexo(p_pasta text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.denuncias d
                  where d.id::text = p_pasta and d.criado_em > now() - interval '1 day')
$$;

create or replace function public.denuncia_anexo_visivel(p_pasta text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.denuncias d
                  where d.id::text = p_pasta and public.denuncia_pode_ver(d.envolve_rh))
$$;

revoke all on function public.denuncia_aceita_anexo(text), public.denuncia_anexo_visivel(text) from public;
grant execute on function public.denuncia_aceita_anexo(text) to anon, authenticated;
grant execute on function public.denuncia_anexo_visivel(text) to authenticated;

drop policy if exists denuncias_anexo_enviar on storage.objects;
create policy denuncias_anexo_enviar on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'denuncias' and public.denuncia_aceita_anexo((storage.foldername(name))[1]));

drop policy if exists denuncias_anexo_ler on storage.objects;
create policy denuncias_anexo_ler on storage.objects
  for select to authenticated
  using (bucket_id = 'denuncias' and public.denuncia_anexo_visivel((storage.foldername(name))[1]));
