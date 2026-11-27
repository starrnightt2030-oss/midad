# موسيقى ومؤثرات الخلفية

طبقتان فوق صوت الراوي، يشتغلوا مع بعض، ومستواهم مستقل عنه:

1. **موسيقى الخلفية**: تتختار تلقائيًا حسب نوع القصة (كلمات العنوان/النوع/القسم، ثم تصنيفات المشهد الحي)، والمستمع يقدر يثبّت مقطوعة أو يقفلها. الإعداد محفوظ.
2. **مؤثر صوتي** اختياري (مطر، بحر، ليل، عصافير...).

| المعرّف | الاسم | يناسب | مكانه |
|---|---|---|---|
| calm | بيانو هادئ | تأمل، شتاء، الافتراضي | داخل التطبيق |
| lullaby | تهويدة النوم | نوم، أطفال | `content/music/` (يُبث ثم يُحفظ على الجهاز) |
| oriental | ليالي شرقية (مقام حجاز، ناي وعود) | روحاني، تراث | `content/music/` |
| strings | أوتار دافئة | حكمة، دراما | `content/music/` |
| harp | حلم القيثارة | خيال، طبيعة | `content/music/` |
| mystery | غموض لطيف | غموض، مغامرة | `content/music/` |
| morning | صباح مشرق | أمل، أطفال | `content/music/` |

المقطوعات غير المدمجة تُبث من `raw.githubusercontent.com` أول مرة وتتحفظ على الجهاز، فحجم التطبيق ما يزيدش، وبدون إنترنت يرجع للبيانو المدمج.

## الترخيص

- الموسيقى مؤلفة في `tools/ambience/compose_music.py` (تأليف خوارزمي ببذرة ثابتة) ومعزوفة بمكتبة أصوات **FluidR3_GM** (رخصة MIT، Frank Wen). الناتج ملك المشروع ومسموح نشره في المتجر.
- المؤثرات الجديدة (night, birds, thunder, softnoise) مُصنّعة رياضيًا في `tools/ambience/make_effects.py` بدون أي تسجيلات خارجية.

## إعادة التوليد

```bash
sudo apt-get install fluidsynth fluid-soundfont-gm ffmpeg
pip install pretty_midi numpy
python tools/ambience/compose_music.py /tmp/music          # أو أسماء معيّنة: ... /tmp/music calm lullaby
python tools/ambience/make_effects.py /tmp/fx
```

ثم انسخ `calm.m4a` والمؤثرات إلى `content/ambience/` والباقي إلى `content/music/`.

لإضافة مقطوعة جديدة: أضفها في `content/catalog.json` بـ `"kind": "music"` و`"moods": [...]`، أو من جدول `ambience` في Supabase (يكمّل القائمة المدمجة).
