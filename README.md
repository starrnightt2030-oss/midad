<div align="center">

<img src="assets/brand/logo.png" width="160" alt="أثير" />

# أثير — ATHEER
**قصص وحكايات .. وحكم من الحياة**

تطبيق عربي للكتب والحكايات المسموعة والمقروءة: عوالم ومواضيع تدور حولها المسموعات،
وقراءة حية يظهر فيها الكلام كلمة كلمة مع صوت الراوي.

تصميم وتطوير **Mohamedd-Eldawly**

[⬇️ تحميل آخر نسخة APK](../../releases/latest)

</div>

---

## المميزات
- **شاشة بداية سينمائية** بنغمة مميزة (يمكن إيقاف الصوت من «عن التطبيق»).
- **العوالم**: الحكايات، المعرفة، الروح، الذات، التأملات — كل عالم كوكب والمسموعات تدور حوله، وتنقّل سينمائي بالسحب أو الأسهم.
- **رف ثلاثي الأبعاد** داخل كل عالم، وصفحة لكل عمل بفصوله.
- **مشغّل دائري** يتلوّن بلون العالم: سرعة، تقديم/رجوع، مؤقت نوم، أجواء استماع (موسيقى هادئة، مطر، بحر، ليل).
- **قراءة حية سينمائية**: الكلمة المسموعة تضيء، والسطور تنساب، مع اسم ولون المتحدث.
- **وضع الصفحة**: ورق دافئ، السطر المسموع مظلّل، اضغط سطرًا لسماعه.
- **صانع الخواطر**: حوّل أي سطر إلى بطاقة جميلة وشاركها كصورة.
- **مكتبتي**: أكمل الاستماع، المفضلة، خواطري.
- **تحديثات تلقائية**: المحتوى الجديد يظهر وحده، والإصدار الجديد من التطبيق يظهر في نافذة تحديث أنيقة.

---

## كيف أضيف محتوى؟ (بدون تعديل الكود)

كل المحتوى موجود في مجلد [`content/`](content). التطبيق يقرأه من GitHub مباشرة،
فأي إضافة تظهر للمستخدمين تلقائيًا **بدون بناء نسخة جديدة**.

### الطريقة ١ — من موقع GitHub مباشرة
1. أنشئ ملف الفصل داخل `content/chapters/` مثل `night-journey-ch1.json`:
   ```json
   {
    "title": "البداية",
    "speakers": {
     "الراوي": {"color": "#E8B04B", "voice": "Charon", "style": "راوٍ دافئ بنبرة درامية"},
     "ليلى":  {"color": "#F2B8D8", "voice": "Aoede",  "style": "فتاة هادئة"}
    },
    "lines": [
     {"speaker": "الراوي", "text": "كانت الليلة طويلة..."},
     {"speaker": "ليلى", "text": "«هل تسمع ذلك الصوت؟»"}
    ]
   }
   ```
2. أضف العمل في `content/catalog.json` داخل `works`:
   ```json
   {
    "id": "night-journey", "world": "stories", "title": "رحلة الليل", "kind": "قصة",
    "description": "وصف قصير يظهر تحت الغلاف", "art": "storm", "cover": "",
    "narrator": "صوت أثير", "minutes": 0,
    "chapters": [{"id": "ch1", "title": "البداية", "script": "chapters/night-journey-ch1.json", "audio": ""}]
   }
   ```
3. **الغلاف**: ارفع صورة باسم المعرّف في `content/covers/` (مثل `night-journey.jpg`) — تُضبط وتُربط تلقائيًا.
   لو لم ترفع غلافًا، يرسم التطبيق غلافًا فنيًا حسب `art`.
4. احفظ (Commit) — سير العمل **«توليد الصوت والأغلفة»** يولّد الصوت بالذكاء الاصطناعي،
   ويحسب توقيت كل كلمة للقراءة الحية، ويضبط الغلاف، ويحفظ كل شيء تلقائيًا.

### الطريقة ٢ — من جهازك بالأداة
```bash
pip install google-genai pillow     # ويلزم ffmpeg
export GEMINI_API_KEY=...            # مفتاح مجاني من Google AI Studio

python tools/atheer_studio.py add-work --id night-journey --world stories \
  --title "رحلة الليل" --kind قصة --desc "..." --art storm --cover ~/cover.jpg
python tools/atheer_studio.py add-chapter --work night-journey --title "البداية" --text ch1.txt
python tools/atheer_studio.py voice --work night-journey
python tools/atheer_studio.py check
git add content && git commit -m "رحلة الليل" && git push
```
صيغة الملف النصي `ch1.txt`: سطر لكل جملة، واسم المتحدث قبل النقطتين (السطر بلا اسم = الراوي).

### قيم مفيدة
| الحقل | القيم |
|---|---|
| `world` | `stories` · `knowledge` · `soul` · `self` · `reflections` (أو أضف عالمًا جديدًا في `worlds`) |
| `art` | `storm` · `lantern` · `traveler` · `deepsea` · `mind` · `morning` |
| أصوات Gemini | `Charon` · `Kore` · `Puck` · `Aoede` · `Fenrir` · `Leda` · `Orus` … |

> الفصل بدون صوت يعمل فورًا كنص مع قراءة حية تقديرية، ويتحوّل لصوت حقيقي بعد التوليد.

---

## الإعداد لأول مرة (مرة واحدة)
في المستودع: **Settings ← Secrets and variables ← Actions ← New repository secret**
- `GEMINI_API_KEY` — لتوليد الصوت (من aistudio.google.com).
- `ANDROID_KEYSTORE_B64` — مفتاح التوقيع الثابت (حتى تُثبَّت التحديثات فوق النسخة القديمة).

## الإصدارات والتحديث
- أي تعديل في الكود (`lib/`) يبني APK جديدًا تلقائيًا وينشره في **Releases**.
- لرفع رقم الإصدار عدّل `version:` في `pubspec.yaml` (مثال: `1.1.0+1`).
- التطبيق يتحقق من آخر إصدار عند الفتح ويعرض نافذة «تحديث الآن».

## البنية
```
lib/            كود التطبيق (Flutter)
content/        المحتوى: catalog.json، chapters/، covers/، audio/، ambience/
assets/         الشعار ونغمة البداية
tools/          أثير ستوديو (توليد الصوت والأغلفة) + سكربتات البناء
branding/       أيقونات أندرويد
```

---
© Mohamedd-Eldawly — جميع الحقوق محفوظة.
