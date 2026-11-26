import 'ambient_scene_registry.dart';
import 'ambient_scene_selector.dart';
import 'ambient_shader_manager.dart';

export 'ambient_audio_mixer.dart';
export 'ambient_performance_manager.dart';
export 'ambient_scene.dart';
export 'ambient_scene_registry.dart';
export 'ambient_scene_renderer.dart';
export 'ambient_scene_selector.dart';

/// Atheer Live Scenes Engine — نقطة الدخول للمحرك البصري للمشاهد الحية.
///
/// الوحدات:
/// - [AmbientSceneRegistry]: يقرأ manifest.json وملفات scene.json.
/// - AmbientAssetManager: تحميل كسول للصور مع ذاكرة صغيرة وتخلص من القديم.
/// - [AmbientShaderManager]: برنامج شيدر واحد يُعاد استخدامه لكل المشاهد.
/// - AmbientSceneRenderer (AmbientSceneView): رسم الصورة + الأقنعة + الجسيمات.
/// - AmbientSceneController: ساعة الإطارات المحدودة وإيقافها عند الإخفاء.
/// - AmbientParticleSystem: جسيمات إجرائية بدون حالة.
/// - AmbientPerformanceManager: أوضاع الجودة وتقليل الحركة والخفض التلقائي.
/// - AmbientAudioMixer: الأصوات المحيطية الاختيارية فوق محرك الصوت الحالي.
/// - [AmbientSceneSelector]: الاختيار التلقائي/اليدوي والمفضلة والتفضيلات.
class AmbientSceneEngine {
  AmbientSceneEngine._();

  /// يجهّز المحرك عند بدء التطبيق: يقرأ التعريفات والتفضيلات ويترجم الشيدر مسبقًا.
  static Future<void> init(AmbientSceneSelector selector) async {
    await selector.load();
    // ترجمة مبكرة حتى لا يتأخر أول ظهور للمشغّل.
    AmbientShaderManager.instance.program();
  }
}

/// الاسم المعتمد للمحرك في المواصفات.
typedef AtheerLiveScenesEngine = AmbientSceneEngine;
