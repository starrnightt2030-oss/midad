import '../models.dart';
import '../state/player.dart';
import 'ambient_scene.dart';

/// طبقتان صوتيتان فوق صوت الراوي (بدون استبدال محرك الصوت):
/// ١) موسيقى خلفية هادئة تُختار تلقائيًا حسب نوع القصة ومشهدها (ويمكن تغييرها أو إيقافها).
/// ٢) مؤثر صوتي اختياري (مطر، بحر، ليل...) يشتغل مع الموسيقى في نفس الوقت.
/// أقصى مستوى 0.6 من صوت الراوي حتى لا تؤثر على وضوح الكلام.
class AmbientAudioMixer {
  const AmbientAudioMixer._();

  /// صوت المشهد ← معرّف المؤثر في catalog.json.
  static const sounds = {
    'rain': 'rain',
    'ocean': 'sea',
    'forest': 'forest',
    'fireplace': 'fire',
    'wind': 'wind',
    'stream': 'stream',
    'night': 'night',
    'calm': 'calm',
  };

  static const maxVolume = 0.6;

  /// المؤثر المقترح لمشهد ما (لا يُشغَّل إلا لو اختاره المستخدم).
  static Ambience? suggestion(AmbientScene? scene, List<Ambience> available) {
    final id = sounds[scene?.sound];
    if (id == null) return null;
    for (final a in available) {
      if (a.id == id && !a.isMusic) return a;
    }
    return null;
  }

  /// كلمات في عنوان القصة أو نوعها أو قسمها ← جو موسيقي.
  static const _keywords = {
    'kids': ['أطفال', 'طفل', 'للصغار', 'حواديت', 'حدوتة', 'صغير'],
    'sleep': ['نوم', 'قبل النوم', 'تهويدة', 'هدوء', 'استرخاء'],
    'spiritual': ['إيمان', 'ديني', 'روحاني', 'الأنبياء', 'صحابة', 'قرآن', 'دعاء', 'رمضان'],
    'heritage': ['تراث', 'ألف ليلة', 'شعبي', 'تاريخ', 'تاريخية', 'الصحراء', 'بدوي', 'عربي', 'سلطان', 'خليفة'],
    'wisdom': ['حكمة', 'حكم', 'عبرة', 'موعظة', 'تأمل', 'خاطرة', 'خواطر'],
    'drama': ['فراق', 'حزن', 'دراما', 'اجتماعي', 'عائلة', 'رومانسي'],
    'mystery': ['غموض', 'لغز', 'أسرار', 'جريمة', 'تحقيق', 'رعب', 'مخيف'],
    'adventure': ['مغامرة', 'مغامرات', 'رحلة', 'بحار', 'كنز', 'قراصنة'],
    'fantasy': ['خيال', 'خيالي', 'سحر', 'ساحر', 'أسطورة', 'أساطير', 'تنين', 'جنية'],
    'hope': ['أمل', 'نجاح', 'تحفيز', 'إلهام', 'تفاؤل', 'سعادة'],
    'nature': ['طبيعة', 'غابة', 'حيوان', 'حيوانات', 'بحر', 'جبل'],
  };

  /// الأجواء التي توحي بها القصة: كلمات النص أولًا (أدق)، ثم تصنيفات المشهد.
  static List<String> moodsFor(Work w, {AmbientScene? scene, String? worldName}) {
    final text = '${w.kind} ${worldName ?? ''} ${w.title} ${w.description}';
    final out = <String>[];
    for (final e in _keywords.entries) {
      if (e.value.any(text.contains)) out.add(e.key);
    }
    if (scene != null) out.addAll(scene.categories);
    return out;
  }

  /// يختار موسيقى الخلفية المناسبة للقصة. نفس القصة تأخذ نفس الموسيقى دائمًا.
  static Ambience? pickMusic(Work w, List<Ambience> available, {AmbientScene? scene, String? worldName}) {
    final music = available.where((a) => a.isMusic).toList();
    if (music.isEmpty) return null;
    final moods = moodsFor(w, scene: scene, worldName: worldName);
    for (final m in moods) {
      final fit = music.where((a) => a.moods.contains(m)).toList();
      if (fit.isNotEmpty) return fit[w.id.codeUnits.fold<int>(0, (s, c) => s + c) % fit.length];
    }
    for (final a in music) {
      if (a.moods.contains('default')) return a;
    }
    return music.first;
  }

  static Future<void> play(PlayerController player, Ambience? a) => player.setEffect(a);

  static void volume(PlayerController player, double v) => player.setEffectVolume(v.clamp(0.05, maxVolume));
}
