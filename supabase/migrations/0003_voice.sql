-- أثير — المرحلة الرابعة: توليد الصوت من اللوحة.
-- شغّل هذا الملف مرة واحدة من SQL Editor بعد 0002_admin.sql. آمن للتشغيل أكثر من مرة.

-- طلبات توليد الصوت: اللوحة تضيف طلبًا، وعامل على GitHub Actions ينفّذه كل بضع دقائق.
create table if not exists public.voice_jobs (
  id          bigint generated always as identity primary key,
  work_id     text not null,
  chapter_id  text not null,
  status      text not null default 'pending' check (status in ('pending','running','done','failed')),
  error       text not null default '',
  progress    text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  foreign key (work_id, chapter_id) references public.chapters(work_id, id) on update cascade on delete cascade
);
create index if not exists voice_jobs_status_idx on public.voice_jobs(status, created_at);

drop trigger if exists voice_jobs_touch on public.voice_jobs;
create trigger voice_jobs_touch before update on public.voice_jobs for each row execute function public.touch_updated_at();

alter table public.voice_jobs enable row level security;
drop policy if exists admin_all on public.voice_jobs;
create policy admin_all on public.voice_jobs for all to authenticated using (public.is_admin()) with check (public.is_admin());
