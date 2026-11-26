-- أثير — قاعدة البيانات الأساسية (المرحلة الأولى)
-- شغّل هذا الملف مرة واحدة من Supabase Dashboard ← SQL Editor.
-- آمن للتشغيل أكثر من مرة.

-- ═══════════ الجداول ═══════════

create table if not exists public.worlds (
  id          text primary key,
  name        text not null,
  short       text not null default '',
  tagline     text not null default '',
  color       text not null default '#B794F6',
  art         text not null default 'storm',
  cover       text not null default '',
  sort_order  int  not null default 0,
  is_premium  boolean not null default false,
  published   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.works (
  id             text primary key,
  world_id       text not null references public.worlds(id) on update cascade on delete restrict,
  title          text not null,
  kind           text not null default '',
  description    text not null default '',
  art            text not null default 'storm',
  cover          text not null default '',
  narrator       text not null default '',
  minutes        int  not null default 0,
  scene          text not null default '',          -- مشهد الخلفية المتحركة (المرحلة الرابعة)
  sort_order     int  not null default 0,
  is_premium     boolean not null default false,    -- يحتاج اشتراك
  allow_download boolean not null default false,    -- الاستماع بدون إنترنت
  published      boolean not null default true,
  publish_at     timestamptz,                       -- نشر مجدول (اختياري)
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists works_world_idx on public.works(world_id, sort_order);

create table if not exists public.chapters (
  work_id          text not null references public.works(id) on update cascade on delete cascade,
  id               text not null,
  sort_order       int  not null default 0,
  title            text not null default '',
  script           jsonb not null default '{"speakers":{},"lines":[]}'::jsonb,
  audio            text not null default '',        -- رابط عام (قصص مجانية)
  audio_path       text not null default '',        -- مسار داخل حاوية premium (قصص مدفوعة)
  duration_seconds numeric not null default 0,
  updated_at       timestamptz not null default now(),
  primary key (work_id, id)
);

create table if not exists public.ambience (
  id         text primary key,
  name       text not null,
  icon       text not null default 'music',
  file       text not null,
  sort_order int  not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.app_settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- اشتراكات (تُملأ لاحقًا من RevenueCat في المرحلة الخامسة)
create table if not exists public.entitlements (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  active_until timestamptz,
  source       text not null default '',
  updated_at   timestamptz not null default now()
);

-- ═══════════ تحديث updated_at تلقائيًا ═══════════

create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;

do $$
declare t text;
begin
  foreach t in array array['worlds','works','chapters','ambience','app_settings','entitlements'] loop
    execute format('drop trigger if exists %I_touch on public.%I', t, t);
    execute format('create trigger %I_touch before update on public.%I for each row execute function public.touch_updated_at()', t, t);
  end loop;
end $$;

-- ═══════════ الصلاحيات ═══════════

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

create or replace function public.has_premium() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.entitlements
    where user_id = auth.uid() and (active_until is null or active_until > now())
  );
$$;

create or replace function public.work_visible(w public.works) returns boolean
language sql stable as $$
  select w.published and (w.publish_at is null or w.publish_at <= now());
$$;

alter table public.worlds       enable row level security;
alter table public.works        enable row level security;
alter table public.chapters     enable row level security;
alter table public.ambience     enable row level security;
alter table public.app_settings enable row level security;
alter table public.admins       enable row level security;
alter table public.entitlements enable row level security;

-- القراءة المباشرة للجداول للأدمن فقط؛ التطبيق يقرأ عبر الدوال بالأسفل.
do $$
declare t text;
begin
  foreach t in array array['worlds','works','chapters','ambience','app_settings'] loop
    execute format('drop policy if exists admin_all on public.%I', t);
    execute format('create policy admin_all on public.%I for all to authenticated using (public.is_admin()) with check (public.is_admin())', t);
  end loop;
end $$;

drop policy if exists admins_self on public.admins;
create policy admins_self on public.admins for select to authenticated using (user_id = auth.uid());

drop policy if exists entitlements_self on public.entitlements;
create policy entitlements_self on public.entitlements for select to authenticated using (user_id = auth.uid() or public.is_admin());

-- ═══════════ واجهة التطبيق ═══════════

-- الفهرس بنفس شكل catalog.json القديم (بدون نصوص الفصول)، فيعمل مع التطبيق الحالي.
create or replace function public.catalog_json() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'version', coalesce(to_char(greatest(
        (select max(updated_at) from public.worlds),
        (select max(updated_at) from public.works),
        (select max(updated_at) from public.chapters),
        (select max(updated_at) from public.ambience)), 'YYYY.MM.DD.HH24MISS'), '0'),
    'worlds', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', x.id, 'name', x.name, 'short', x.short, 'tagline', x.tagline,
        'color', x.color, 'art', x.art, 'cover', x.cover, 'premium', x.is_premium)
        order by x.sort_order, x.id)
      from public.worlds x where x.published), '[]'::jsonb),
    'ambience', coalesce((
      select jsonb_agg(jsonb_build_object('id', a.id, 'name', a.name, 'icon', a.icon, 'file', a.file)
        order by a.sort_order, a.id)
      from public.ambience a), '[]'::jsonb),
    'works', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', w.id, 'world', w.world_id, 'title', w.title, 'kind', w.kind,
        'description', w.description, 'art', w.art, 'cover', w.cover,
        'narrator', w.narrator, 'minutes', w.minutes, 'scene', w.scene,
        'premium', (w.is_premium or x.is_premium), 'download', w.allow_download,
        'chapters', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', c.id, 'title', c.title,
            'script', 'sb:' || c.work_id || '/' || c.id,
            'audio', case when (w.is_premium or x.is_premium) then '' else c.audio end)
            order by c.sort_order, c.id)
          from public.chapters c where c.work_id = w.id), '[]'::jsonb))
        order by x.sort_order, w.sort_order, w.id)
      from public.works w join public.worlds x on x.id = w.world_id
      where x.published and public.work_visible(w)), '[]'::jsonb)
  );
$$;

-- نص الفصل وتوقيتاته. المحتوى المدفوع يحتاج اشتراك.
create or replace function public.chapter_json(p_work text, p_chapter text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  w public.works; x public.worlds; c public.chapters; locked boolean;
begin
  select * into w from public.works where id = p_work;
  if not found or not public.work_visible(w) then return null; end if;
  select * into x from public.worlds where id = w.world_id;
  select * into c from public.chapters where work_id = p_work and id = p_chapter;
  if not found then return null; end if;
  locked := (w.is_premium or x.is_premium) and not public.has_premium() and not public.is_admin();
  if locked then
    return jsonb_build_object('locked', true, 'title', c.title);
  end if;
  return c.script || jsonb_build_object(
    'title', c.title,
    'audio', c.audio,
    'audio_path', c.audio_path,
    'duration', c.duration_seconds);
end $$;

grant execute on function public.catalog_json() to anon, authenticated;
grant execute on function public.chapter_json(text, text) to anon, authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.has_premium() to authenticated;

-- ═══════════ التخزين ═══════════
-- covers و audio: عامة للقراءة. premium: خاصة، للمشتركين فقط.

insert into storage.buckets (id, name, public) values
  ('covers', 'covers', true),
  ('audio', 'audio', true),
  ('premium', 'premium', false)
on conflict (id) do nothing;

drop policy if exists "atheer admin write" on storage.objects;
create policy "atheer admin write" on storage.objects for all to authenticated
  using (bucket_id in ('covers','audio','premium') and public.is_admin())
  with check (bucket_id in ('covers','audio','premium') and public.is_admin());

drop policy if exists "atheer premium read" on storage.objects;
create policy "atheer premium read" on storage.objects for select to authenticated
  using (bucket_id = 'premium' and (public.has_premium() or public.is_admin()));
