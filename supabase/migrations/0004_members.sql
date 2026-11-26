-- أثير — المرحلة الخامسة: حسابات المستمعين والاشتراك.
-- شغّل هذا الملف مرة واحدة من SQL Editor بعد 0003_voice.sql. آمن للتشغيل أكثر من مرة.

-- حالة اشتراك المستمع الحالي.
create or replace function public.my_status() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'signed_in', auth.uid() is not null,
    'premium', public.has_premium(),
    'until', (select active_until from public.entitlements where user_id = auth.uid()),
    'admin', public.is_admin());
$$;
grant execute on function public.my_status() to anon, authenticated;

-- معلومات عامة للتطبيق (طريقة الاشتراك والسعر...) يحرّرها الأدمن من اللوحة.
create or replace function public.app_info() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from public.app_settings where key like 'public.%';
$$;
grant execute on function public.app_info() to anon, authenticated;

-- الأدمن: بحث عن مستمع بالبريد.
create or replace function public.admin_find_users(p_query text default '') returns jsonb
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', u.id, 'email', u.email, 'created_at', u.created_at,
      'until', e.active_until, 'premium', e.user_id is not null and (e.active_until is null or e.active_until > now()),
      'source', e.source)
      order by u.created_at desc)
    from (select * from auth.users
          where coalesce(p_query, '') = '' or email ilike '%' || p_query || '%'
          order by created_at desc limit 50) u
    left join public.entitlements e on e.user_id = u.id), '[]'::jsonb);
end $$;
grant execute on function public.admin_find_users(text) to authenticated;

-- الأدمن: تفعيل الاشتراك حتى تاريخ (null = دائم) أو إلغاؤه.
create or replace function public.admin_set_premium(p_user uuid, p_on boolean, p_until timestamptz default null) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then return false; end if;
  if p_on then
    insert into public.entitlements(user_id, active_until, source) values (p_user, p_until, 'manual')
    on conflict (user_id) do update set active_until = excluded.active_until, source = 'manual';
  else
    delete from public.entitlements where user_id = p_user;
  end if;
  return true;
end $$;
grant execute on function public.admin_set_premium(uuid, boolean, timestamptz) to authenticated;

-- إحصائيات اللوحة: نضيف المستمعين والمشتركين.
create or replace function public.admin_stats() returns jsonb
language sql stable security definer set search_path = public, auth as $$
  select case when not public.is_admin() then null else jsonb_build_object(
    'worlds', (select count(*) from public.worlds),
    'works', (select count(*) from public.works),
    'published', (select count(*) from public.works where published),
    'premium', (select count(*) from public.works where is_premium),
    'chapters', (select count(*) from public.chapters),
    'with_audio', (select count(*) from public.chapters where audio <> '' or audio_path <> ''),
    'users', (select count(*) from auth.users),
    'subscribers', (select count(*) from public.entitlements where active_until is null or active_until > now())
  ) end;
$$;
