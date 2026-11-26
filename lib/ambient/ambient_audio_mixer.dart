import '../models.dart';
import '../state/player.dart';
import 'ambient_scene.dart';

/// الأصوات المحيطية الاختيارية: طبقة رقيقة فوق محرك الصوت الحالي (PlayerController)
/// بدون استبداله. مغلقة افتراضيًا، ومستواها مستقل عن صوت الراوي
/// (أقصى مستوى 0.6 من صوت الراوي حتى لا تؤثر على وضوح الكلام).
class AmbientAudioMixer {
  const AmbientAudioMixer._();

  /// الأصوات المدعومة ← معرّف الصوت في catalog.json.
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

  /// الصوت المقترح لمشهد ما (لا يُشغَّل إلا لو اختاره المستخدم).
  static Ambience? suggestion(AmbientScene? scene, List<Ambience> available) {
    final id = sounds[scene?.sound];
    if (id == null) return null;
    for (final a in available) {
      if (a.id == id) return a;
    }
    return null;
  }

  static Future<void> play(PlayerController player, Ambience? a) => player.setAmbience(a);

  static void volume(PlayerController player, double v) => player.setAmbienceVolume(v.clamp(0.05, maxVolume));
}
