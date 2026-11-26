-- أثير — تشغيل «ضبط التوقيت» و«توليد الصوت» فورًا بدل انتظار جدولة GitHub (التي قد تتأخر ساعات).
-- عند إضافة طلب في voice_jobs تطلب قاعدة البيانات من GitHub تشغيل workflow «توليد الصوت» مباشرة.
-- الجدولة كل ١٠ دقائق تبقى احتياطًا. آمن للتشغيل أكثر من مرة.
--
-- بعد تشغيل هذا الملف، احفظ مفتاح GitHub مرة واحدة (في SQL Editor نفسه):
--   select vault.create_secret('github_pat_...', 'github_dispatch_token');
-- لتغيير المفتاح لاحقًا:
--   select vault.update_secret((select id from vault.secrets where name = 'github_dispatch_token'), 'github_pat_...');
-- بدون المفتاح لا يحدث شيء، ويبقى العمل على الجدولة كما كان.

create extension if not exists pg_net with schema extensions;

create or replace function public.dispatch_voice_worker()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  tok text;
begin
  select decrypted_secret into tok from vault.decrypted_secrets where name = 'github_dispatch_token' limit 1;
  if coalesce(tok, '') = '' then
    return null;
  end if;
  perform net.http_post(
    url := 'https://api.github.com/repos/starrnightt2030-oss/midad/actions/workflows/voice.yml/dispatches',
    body := jsonb_build_object('ref', 'main'),
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || tok,
      'Accept', 'application/vnd.github+json',
      'X-GitHub-Api-Version', '2022-11-28',
      'User-Agent', 'atheer-voice-dispatch',
      'Content-Type', 'application/json'));
  return null;
exception when others then
  -- لا نمنع حفظ الطلب أبدًا؛ الجدولة ستلتقطه.
  return null;
end;
$$;

revoke all on function public.dispatch_voice_worker() from public, anon, authenticated;

-- مرة واحدة لكل عملية إضافة (حتى لو أُضيفت عدة طلبات معًا)؛ العامل ينفّذ كل الطلبات المنتظرة.
drop trigger if exists voice_jobs_dispatch on public.voice_jobs;
create trigger voice_jobs_dispatch
  after insert on public.voice_jobs
  for each statement execute function public.dispatch_voice_worker();
