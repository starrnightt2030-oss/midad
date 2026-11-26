-- أثير — المرحلة الثالثة: لوحة الإدارة
-- شغّل هذا الملف مرة واحدة من SQL Editor بعد 0001_init.sql. آمن للتشغيل أكثر من مرة.

-- أول حساب يسجّل دخول للوحة يطلب أن يكون أدمن.
-- تنجح فقط لو لا يوجد أي أدمن بعد؛ بعدها الأدمن يضيف غيره من اللوحة.
create or replace function public.claim_admin() returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return false; end if;
  if exists (select 1 from public.admins) then
    return exists (select 1 from public.admins where user_id = auth.uid());
  end if;
  insert into public.admins(user_id) values (auth.uid());
  return true;
end $$;
grant execute on function public.claim_admin() to authenticated;

-- الأدمن يقدر يشوف ويضيف أدمن آخرين.
drop policy if exists admins_manage on public.admins;
create policy admins_manage on public.admins for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- إحصائيات سريعة للوحة.
create or replace function public.admin_stats() returns jsonb
language sql stable security definer set search_path = public as $$
  select case when not public.is_admin() then null else jsonb_build_object(
    'worlds', (select count(*) from public.worlds),
    'works', (select count(*) from public.works),
    'published', (select count(*) from public.works where published),
    'premium', (select count(*) from public.works where is_premium),
    'chapters', (select count(*) from public.chapters),
    'with_audio', (select count(*) from public.chapters where audio <> '' or audio_path <> '')
  ) end;
$$;
grant execute on function public.admin_stats() to authenticated;
