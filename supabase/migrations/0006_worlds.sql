-- أثير — «عوالم أثير»: أقسام ديناميكية بهوية بصرية لكل قسم.
-- شغّل هذا الملف مرة واحدة من SQL Editor بعد 0005. آمن للتشغيل أكثر من مرة.
-- لا يحذف أي قسم أو قصة موجودة، ولا يغيّر قسم أي قصة.

-- ═══════════ أعمدة جديدة للأقسام ═══════════
-- published = القسم مفعّل (لو اتعطّل تختفي قصصه اللي مالهاش قسم مفعّل تاني).
-- visible   = القسم ظاهر في صفحة «عوالم أثير» (لو مخفي، قصصه تفضل تظهر في البحث والرئيسية).
-- empty_mode = لو القسم فاضي: 'soon' يظهر «قريبًا»، 'hide' يختفي.
alter table public.worlds add column if not exists description text not null default '';
alter table public.worlds add column if not exists color2      text not null default '';
alter table public.worlds add column if not exists visible     boolean not null default true;
alter table public.worlds add column if not exists empty_mode  text not null default 'soon';

-- ═══════════ عدّاد الاستماع (للأكثر استماعًا) ═══════════
alter table public.works add column if not exists plays bigint not null default 0;

create or replace function public.count_play(p_work text) returns void
language sql volatile security definer set search_path = public as $$
  update public.works set plays = plays + 1 where id = p_work and published;
$$;
grant execute on function public.count_play(text) to anon, authenticated;

-- التريجر بتاع updated_at كان هيغيّر نسخة الفهرس مع كل استماع؛ نتجاهل تغيير plays لوحده.
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  if tg_table_name = 'works' and (to_jsonb(new) - 'plays' - 'updated_at') = (to_jsonb(old) - 'plays' - 'updated_at') then
    return new;
  end if;
  new.updated_at = now();
  return new;
end $$;

-- ═══════════ ربط القصة بأكثر من قسم ═══════════
-- works.world_id يفضل القسم الأساسي. الجدول ده للأقسام الإضافية.
create table if not exists public.work_worlds (
  work_id    text not null references public.works(id)  on update cascade on delete cascade,
  world_id   text not null references public.worlds(id) on update cascade on delete cascade,
  created_at timestamptz not null default now(),
  primary key (work_id, world_id)
);
create index if not exists work_worlds_world_idx on public.work_worlds(world_id);
alter table public.work_worlds enable row level security;
drop policy if exists admin_all on public.work_worlds;
create policy admin_all on public.work_worlds for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ═══════════ الأقسام الـ16 ═══════════
-- الصورة الافتراضية لكل قسم موجودة داخل التطبيق (assets/categories/<id>.webp)؛ cover يفضل فاضي
-- إلا لو الأدمن رفع صورة بديلة.
insert into public.worlds (id, name, short, tagline, description, color, color2, art, sort_order)
select v.* from (values
  ('heartfelt_messages', 'رسائل من القلب', 'رسائل من القلب', 'كلمات تصل إلى أعماق قلبك',
   'رسائل إنسانية مؤثرة، ومواساة، وكلمات يحتاج الإنسان إلى سماعها في أوقات مختلفة من حياته.', '#E8A0A8', '#D4AF6A', 'rose', 1),
  ('meaningful_words', 'كلمات لها معنى', 'كلمات لها معنى', 'كلمات قليلة... ومعانٍ لا تنتهي',
   'حكم ومواعظ وتأملات تحمل معاني عميقة ودروسًا مستفادة من الحياة.', '#E9DCC0', '#8B5E3C', 'quill', 2),
  ('real_stories', 'قصص من الواقع', 'قصص من الواقع', 'حكايات عاشها أناس مثلنا',
   'قصص حقيقية وتجارب إنسانية ومواقف واقعية تحمل العبرة والأمل والدروس المستفادة.', '#E3A35B', '#7A3E2B', 'film', 3),
  ('from_the_archive', 'من الأرشيف', 'من الأرشيف', 'حكايات طواها الزمن ولم ينسها الأثر',
   'حكايات من الماضي وأحداث تاريخية وقصص منسية تستحق أن تُروى من جديد.', '#C08A52', '#6B4226', 'archive', 4),
  ('quran_stories', 'قصص من القرآن', 'قصص من القرآن', 'قصص خالدة وعبر لا تنتهي',
   'القصص الواردة في القرآن الكريم بأسلوب سردي مؤثر، مع الالتزام بالمصادر الصحيحة واستخلاص العبر والدروس.', '#3FA37A', '#D4AF37', 'mushaf', 5),
  ('biographies', 'سيرة ومسيرة', 'سيرة ومسيرة', 'حياة تُروى... وأثر يبقى',
   'سير الأنبياء والصحابة والعلماء والشخصيات المؤثرة وأصحاب الإنجازات، مع توثيق الروايات.', '#C9925A', '#5E4330', 'compass', 6),
  ('bedtime_stories', 'قبل أن تنام', 'قبل أن تنام', 'دع ضجيج اليوم يرحل',
   'قصص هادئة وحكايات مسموعة وكلمات مطمئنة تساعد على الاسترخاء والاستعداد للنوم.', '#A58CF0', '#1C2457', 'moon', 7),
  ('self_discovery', 'رحلة إلى الذات', 'رحلة إلى الذات', 'اكتشف نفسك من جديد',
   'تنمية الذات والثقة بالنفس وفهم المشاعر وتطوير الشخصية والتعامل مع ضغوط الحياة.', '#8FD694', '#2F5D3A', 'sprout', 8),
  ('tranquility', 'طمأنينة', 'طمأنينة', 'هنا يجد قلبك بعض السلام',
   'كلمات عن السكينة والصبر والرضا والتوكل والتعامل مع الحزن والقلق وضغوط الحياة.', '#5ED3E0', '#1E6F8F', 'feather', 9),
  ('life_lessons', 'علمتني الحياة', 'علمتني الحياة', 'لكل تجربة درس... ولكل درس أثر',
   'دروس الحياة والتجارب والمواقف الإنسانية التي تغير نظرة الإنسان إلى العالم.', '#F0B35A', '#8A4B12', 'hourglass', 10),
  ('hope_after_hardship', 'بعد العسر يسر', 'بعد العسر يسر', 'مهما طال الليل... سيأتي الصباح',
   'قصص تجاوز المحن والابتلاءات والفشل والعودة إلى الحياة بأمل جديد.', '#F5C26B', '#2A1A12', 'door', 11),
  ('wisdom_minutes', 'دقائق من الحكمة', 'دقائق من الحكمة', 'دقائق قليلة قد تغير الكثير',
   'حكم وخواطر ومواعظ صوتية قصيرة تتراوح مدتها بين دقيقة وخمس دقائق.', '#D4AF37', '#121212', 'watch', 12),
  ('between_hearts', 'بين القلوب', 'بين القلوب', 'لأن أجمل ما في الحياة هو الإنسان',
   'العلاقات الإنسانية والزواج والصداقة والأسرة والحب والتسامح وفهم الآخرين.', '#E7A6B5', '#7D8B52', 'olive', 13),
  ('nostalgic_tales', 'حكايات زمان', 'حكايات زمان', 'رحلة إلى زمن لا يغيب عن الذاكرة',
   'حكايات التراث الشعبي والذكريات الجميلة والحياة في الزمن القديم.', '#E2B77E', '#5B4A3A', 'train', 14),
  ('turning_point', 'نقطة تحول', 'نقطة تحول', 'لحظة واحدة قد تغير مسار الحياة',
   'قصص القرارات المصيرية والمواقف التي غيرت حياة أصحابها بالكامل.', '#4FC08D', '#D4AF37', 'butterfly', 15),
  ('spiritual_nourishment', 'زاد الروح', 'زاد الروح', 'ما يحيي القلب ويغذي الروح',
   'خواطر إيمانية ومواعظ وتدبر ومعانٍ روحانية تقرب الإنسان من الله.', '#E9DFC7', '#2E7D5B', 'beads', 16)
) v(id, name, short, tagline, description, color, color2, art, sort_order)
-- القسم الموجود بنفس الاسم (حتى بمعرّف تاني) مش بيتكرر.
where not exists (select 1 from public.worlds w where w.id = v.id or regexp_replace(translate(w.name, 'أإآةى', 'اااهي'), '[[:space:].«»ـ-]', '', 'g') = regexp_replace(translate(v.name, 'أإآةى', 'اااهي'), '[[:space:].«»ـ-]', '', 'g'))
on conflict (id) do nothing;

-- الأقسام القديمة (لو موجودة) تنزل بعد الـ16 بنفس ترتيبها؛ الأدمن يقدر يغيّر الترتيب بعدين.
update public.worlds set sort_order = sort_order + 100
where sort_order < 100
  and regexp_replace(translate(name, 'أإآةى', 'اااهي'), '[[:space:].«»ـ-]', '', 'g') not in (select regexp_replace(translate(n, 'أإآةى', 'اااهي'), '[[:space:].«»ـ-]', '', 'g') from unnest(array['رسائل من القلب','كلمات لها معنى','قصص من الواقع','من الأرشيف','قصص من القرآن','سيرة ومسيرة','قبل أن تنام','رحلة إلى الذات','طمأنينة','علمتني الحياة','بعد العسر يسر','دقائق من الحكمة','بين القلوب','حكايات زمان','نقطة تحول','زاد الروح']) n)
  and id not in (
  'heartfelt_messages','meaningful_words','real_stories','from_the_archive','quran_stories','biographies',
  'bedtime_stories','self_discovery','tranquility','life_lessons','hope_after_hardship','wisdom_minutes',
  'between_hearts','nostalgic_tales','turning_point','spiritual_nourishment');

-- الأقسام اللي اتضافت قبل الملف ده (من GitHub) ناقصها الوصف واللون الثاني.
update public.worlds w set description = v.description, color2 = v.color2
from (values
  ('heartfelt_messages', 'رسائل إنسانية مؤثرة، ومواساة، وكلمات يحتاج الإنسان إلى سماعها في أوقات مختلفة من حياته.', '#D4AF6A'),
  ('meaningful_words', 'حكم ومواعظ وتأملات تحمل معاني عميقة ودروسًا مستفادة من الحياة.', '#8B5E3C'),
  ('real_stories', 'قصص حقيقية وتجارب إنسانية ومواقف واقعية تحمل العبرة والأمل والدروس المستفادة.', '#7A3E2B'),
  ('from_the_archive', 'حكايات من الماضي وأحداث تاريخية وقصص منسية تستحق أن تُروى من جديد.', '#6B4226'),
  ('quran_stories', 'القصص الواردة في القرآن الكريم بأسلوب سردي مؤثر، مع الالتزام بالمصادر الصحيحة واستخلاص العبر والدروس.', '#D4AF37'),
  ('biographies', 'سير الأنبياء والصحابة والعلماء والشخصيات المؤثرة وأصحاب الإنجازات، مع توثيق الروايات.', '#5E4330'),
  ('bedtime_stories', 'قصص هادئة وحكايات مسموعة وكلمات مطمئنة تساعد على الاسترخاء والاستعداد للنوم.', '#1C2457'),
  ('self_discovery', 'تنمية الذات والثقة بالنفس وفهم المشاعر وتطوير الشخصية والتعامل مع ضغوط الحياة.', '#2F5D3A'),
  ('tranquility', 'كلمات عن السكينة والصبر والرضا والتوكل والتعامل مع الحزن والقلق وضغوط الحياة.', '#1E6F8F'),
  ('life_lessons', 'دروس الحياة والتجارب والمواقف الإنسانية التي تغير نظرة الإنسان إلى العالم.', '#8A4B12'),
  ('hope_after_hardship', 'قصص تجاوز المحن والابتلاءات والفشل والعودة إلى الحياة بأمل جديد.', '#2A1A12'),
  ('wisdom_minutes', 'حكم وخواطر ومواعظ صوتية قصيرة تتراوح مدتها بين دقيقة وخمس دقائق.', '#121212'),
  ('between_hearts', 'العلاقات الإنسانية والزواج والصداقة والأسرة والحب والتسامح وفهم الآخرين.', '#7D8B52'),
  ('nostalgic_tales', 'حكايات التراث الشعبي والذكريات الجميلة والحياة في الزمن القديم.', '#5B4A3A'),
  ('turning_point', 'قصص القرارات المصيرية والمواقف التي غيرت حياة أصحابها بالكامل.', '#D4AF37'),
  ('spiritual_nourishment', 'خواطر إيمانية ومواعظ وتدبر ومعانٍ روحانية تقرب الإنسان من الله.', '#2E7D5B')
) v(id, description, color2)
where w.id = v.id and w.description = '';

-- ═══════════ الفهرس ═══════════
-- نفس الشكل القديم (التطبيق القديم يكمل يشتغل)، مع:
-- worlds: description, color2, visible, empty_mode, cover
-- works : worlds (كل أقسام القصة المفعّلة)، plays، added
create or replace function public.catalog_json() returns jsonb
language sql stable security definer set search_path = public as $$
  with vis as (
    select w.*,
      (select coalesce(jsonb_agg(z.id order by z.sort_order, z.id), '[]'::jsonb) from public.worlds z
        where z.published and (z.id = w.world_id
          or exists (select 1 from public.work_worlds ww where ww.work_id = w.id and ww.world_id = z.id))) as wids,
      coalesce((select x.is_premium from public.worlds x where x.id = w.world_id), false) as world_premium
    from public.works w
    where public.work_visible(w)
  )
  select jsonb_build_object(
    'version', coalesce(to_char(greatest(
        (select max(updated_at) from public.worlds),
        (select max(updated_at) from public.works),
        (select max(updated_at) from public.chapters),
        (select max(updated_at) from public.ambience),
        (select max(created_at) from public.work_worlds)), 'YYYY.MM.DD.HH24MISS'), '0')
      || '-' || (select count(*) from public.work_worlds)::text,
    'worlds', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', x.id, 'name', x.name, 'short', x.short, 'tagline', x.tagline,
        'description', x.description, 'color', x.color, 'color2', x.color2,
        'visible', x.visible, 'empty_mode', x.empty_mode,
        'art', x.art, 'cover', x.cover, 'premium', x.is_premium)
        order by x.sort_order, x.id)
      from public.worlds x where x.published), '[]'::jsonb),
    'ambience', coalesce((
      select jsonb_agg(jsonb_build_object('id', a.id, 'name', a.name, 'icon', a.icon, 'file', a.file)
        order by a.sort_order, a.id)
      from public.ambience a), '[]'::jsonb),
    'works', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', w.id, 'world', case when w.wids ? w.world_id then w.world_id else w.wids->>0 end, 'worlds', w.wids, 'title', w.title, 'kind', w.kind,
        'description', w.description, 'art', w.art, 'cover', w.cover,
        'narrator', w.narrator, 'minutes', w.minutes, 'scene', w.scene,
        'plays', w.plays, 'added', coalesce(w.publish_at, w.created_at),
        'premium', (w.is_premium or w.world_premium), 'download', w.allow_download,
        'chapters', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', c.id, 'title', c.title,
            'script', 'sb:' || c.work_id || '/' || c.id,
            'audio', case when (w.is_premium or w.world_premium) then '' else c.audio end)
            order by c.sort_order, c.id)
          from public.chapters c where c.work_id = w.id), '[]'::jsonb))
        order by w.sort_order, w.id)
      from vis w where jsonb_array_length(w.wids) > 0), '[]'::jsonb)
  );
$$;
grant execute on function public.catalog_json() to anon, authenticated;
