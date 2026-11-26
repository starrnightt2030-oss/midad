# المشاهد الحية — Atheer Live Scenes Engine

خلفيات حية بأسلوب Cinemagraph في شاشة التشغيل ومكتبة «أجواء أثير».
الحركة موضعية داخل أقنعة لكل مشهد، والمباني والصخور والأثاث ثابتة تمامًا.

## البنية (`lib/ambient/`)

| الوحدة | الملف | الدور |
|---|---|---|
| AmbientSceneEngine / AtheerLiveScenesEngine | `ambient_scene_engine.dart` | نقطة الدخول والتهيئة |
| AmbientSceneRegistry | `ambient_scene_registry.dart` | قراءة `manifest.json` و`scene.json` |
| AmbientAssetManager | `ambient_asset_manager.dart` | تحميل كسول للصور، ذاكرة صغيرة (٤ صور) مع dispose |
| AmbientShaderManager | `ambient_shader_manager.dart` | برنامج شيدر واحد مشترك، ورجوع لخلفية ثابتة لو فشل |
| AmbientSceneRenderer | `ambient_scene_renderer.dart` | `AmbientSceneView`: صورة + أقنعة + جسيمات عبر CustomPainter |
| AmbientSceneController | `ambient_scene_controller.dart` | Ticker بمعدل إطارات محدود، يتوقف عند الإخفاء والخلفية |
| AmbientParticleSystem | `ambient_particle_system.dart` | جسيمات إجرائية بلا حالة بنداء `drawRawAtlas` واحد لكل باعث |
| AmbientPerformanceManager | `ambient_performance_manager.dart` | أوضاع الجودة، تقليل الحركة، الخفض التلقائي حسب زمن الإطار |
| AmbientAudioMixer | `ambient_audio_mixer.dart` | الأصوات المحيطية فوق `PlayerController` الحالي |
| AmbientSceneSelector | `ambient_scene_selector.dart` | تلقائي/يدوي، المفضلة، حفظ التفضيلات |

الشيدر: `shaders/ambient_scene.frag` (GLSL). يأخذ الصورة والقناع بنفس تحويل `BoxFit.cover`،
ويطبّق حتى ٤ مؤثرات، كل مؤثر داخل قناة من القناع (R/G/B):
`ripple, flow, drift, glow, mist, sway, aurora, twinkle, waves, rays`.

## ملفات المشهد

```
assets/ambient/<id>/background.webp   الصورة
assets/ambient/<id>/mask.webp         القناع (RGB بدون فقد)
assets/ambient/<id>/thumb.webp        صورة مصغرة للمكتبة
assets/ambient/<id>/scene.json        العنوان، التصنيفات، المؤثرات، الجسيمات، الصوت المقترح
```

مصدر الأقنعة قابل للتعديل: `tools/ambient/masks/<id>.json` (مضلعات بإحداثيات نسبية + تنقية باللون).

```
python3 tools/ambient/build_masks.py <id> --preview /tmp/masks   # يبني القناع ويحفظ صورة تحقق
```

## استبدال مشهد مؤقت بصورة أصلية

المشاهد التي `source_quality = collage_preview` نسخ صغيرة (252×303) ويجب استبدالها قبل الإصدار النهائي:
`06_cozy_library, 08_mountain_sunrise, 10_mosque_courtyard, 17_campfire_night, 18_sunlight_garden, 19_northern_lights`.

1. احفظ الصورة الجديدة (9:16، يفضل 941×1672 أو أكبر) كـ `background.webp` و`thumb.webp`.
2. عدّل `width/height/source_quality` في `scene.json`.
3. عدّل مضلعات `tools/ambient/masks/<id>.json` لتطابق الصورة الجديدة، وغيّر `scale` إلى 0.5، ثم شغّل `build_masks.py` وراجع صورة التحقق.
4. شغّل `flutter test` (اختبار `ambient_render_test` يرسم كل المشاهد بالشيدر فعليًا).

لحفظ إطارات للمراجعة البصرية: `AMBIENT_FRAMES=/tmp/frames AMBIENT_SCENE=<id> AMBIENT_CLIP=4 flutter test test/ambient_render_test.dart`.

## أوضاع الجودة

| الوضع | إطارات/ث | الشيدر | الجسيمات |
|---|---|---|---|
| سينمائي | 30 | كامل | كاملة |
| متوازن (افتراضي) | 24 | 80٪ | 60٪ |
| اقتصادي | 15 | 55٪ | 30٪ |
| ثابت | 0 | — | — |
| النوم | 15 ثم توقف | يخفت تدريجيًا حتى السواد خلال ٣ دقائق، والصوت مستمر |

«تقليل الحركة» في النظام يحوّل أي وضع إلى ثابت (عدا وضع النوم). الخفض التلقائي ينزل درجة لو تجاوز
المئين ٩٠ لزمن الإطار 26ms، ويرجع بعد أربع نوافذ جيدة.
