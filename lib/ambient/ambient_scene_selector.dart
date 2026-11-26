import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ambient_performance_manager.dart';
import 'ambient_scene.dart';
import 'ambient_scene_registry.dart';

/// اختيار المشهد وتفضيلات المستخدم: تلقائي (حسب جو القصة) أو يدوي، والمفضلة، ووضع الجودة.
/// كل شيء محفوظ في SharedPreferences.
class AmbientSceneSelector extends ChangeNotifier {
  AmbientSceneSelector({AmbientSceneRegistry? registry}) : registry = registry ?? AmbientSceneRegistry.instance;

  final AmbientSceneRegistry registry;

  static const _kMode = 'ambient.mode';
  static const _kScene = 'ambient.scene';
  static const _kFavs = 'ambient.favs';
  static const _kQuality = 'ambient.quality';
  static const _kAdapt = 'ambient.autoAdapt';

  bool manual = false;
  String? manualId;
  final Set<String> favorites = {};
  AmbientQuality quality = AmbientQuality.balanced;
  bool autoAdapt = true;
  bool loaded = false;

  Future<void> load() async {
    await registry.load();
    try {
      final p = await SharedPreferences.getInstance();
      manual = p.getString(_kMode) == 'manual';
      manualId = p.getString(_kScene);
      favorites
        ..clear()
        ..addAll(p.getStringList(_kFavs) ?? const []);
      quality = AmbientQuality.parse(p.getString(_kQuality));
      autoAdapt = p.getBool(_kAdapt) ?? true;
    } catch (e) {
      debugPrint('ambient prefs failed: $e');
    }
    AmbientPerformanceManager.instance.autoAdapt = autoAdapt;
    loaded = true;
    notifyListeners();
  }

  Future<void> _save(void Function(SharedPreferences p) f) async {
    try {
      f(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  /// المشهد المناسب: اليدوي لو اختاره المستخدم، وإلا حسب جو القصة ([mood] مثل rain/sea/night).
  AmbientScene? sceneFor({String? workId, String? mood}) {
    if (!registry.loaded) return null;
    if (manual && manualId != null && registry[manualId!] != null) return registry[manualId!];
    final pool = registry.forMood(mood ?? 'night');
    final list = pool.isNotEmpty ? pool : registry.scenes.where((s) => !s.lowRes && !s.categories.contains('fantasy')).toList();
    if (list.isEmpty) return registry.scenes.isEmpty ? null : registry.scenes.first;
    // نفس القصة تأخذ نفس المشهد دائمًا، والقصص المختلفة تتنوع.
    final h = (workId ?? '').codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff);
    return list[h % list.length];
  }

  void choose(String id) {
    manual = true;
    manualId = id;
    notifyListeners();
    _save((p) => p
      ..setString(_kMode, 'manual')
      ..setString(_kScene, id));
  }

  void setAuto() {
    manual = false;
    notifyListeners();
    _save((p) => p.setString(_kMode, 'auto'));
  }

  bool isFav(String id) => favorites.contains(id);

  void toggleFav(String id) {
    if (!favorites.remove(id)) favorites.add(id);
    notifyListeners();
    _save((p) => p.setStringList(_kFavs, favorites.toList()));
  }

  void setQuality(AmbientQuality q) {
    quality = q;
    AmbientPerformanceManager.instance.reset();
    notifyListeners();
    _save((p) => p.setString(_kQuality, q.name));
  }

  void setAutoAdapt(bool v) {
    autoAdapt = v;
    AmbientPerformanceManager.instance
      ..autoAdapt = v
      ..reset();
    notifyListeners();
    _save((p) => p.setBool(_kAdapt, v));
  }
}
