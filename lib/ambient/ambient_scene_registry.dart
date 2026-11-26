import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ambient_scene.dart';

/// سجل المشاهد: يقرأ assets/ambient/manifest.json ثم scene.json لكل مشهد.
/// الملفات صغيرة جدًا، أما الصور نفسها فتُحمّل عند الحاجة فقط (AmbientAssetManager).
class AmbientSceneRegistry {
  AmbientSceneRegistry._();
  static final AmbientSceneRegistry instance = AmbientSceneRegistry._();

  static const manifestPath = 'assets/ambient/manifest.json';

  final Map<String, AmbientScene> _scenes = {};
  Future<void>? _loading;

  List<AmbientScene> get scenes => _scenes.values.toList(growable: false);
  bool get loaded => _scenes.isNotEmpty;
  AmbientScene? operator [](String id) => _scenes[id];

  Future<void> load({AssetBundle? bundle}) => _loading ??= _load(bundle ?? rootBundle);

  Future<void> _load(AssetBundle bundle) async {
    try {
      final manifest = jsonDecode(await bundle.loadString(manifestPath)) as Map<String, dynamic>;
      for (final e in (manifest['scenes'] as List)) {
        final id = (e as Map<String, dynamic>)['id'] as String;
        try {
          final j = jsonDecode(await bundle.loadString('assets/ambient/$id/scene.json')) as Map<String, dynamic>;
          _scenes[id] = AmbientScene.fromJson(j);
        } catch (err) {
          debugPrint('ambient scene $id skipped: $err');
        }
      }
    } catch (err) {
      debugPrint('ambient manifest failed: $err');
      _loading = null;
    }
  }

  List<AmbientScene> inCategory(String category) => scenes.where((s) => s.categories.contains(category)).toList();

  /// مشاهد تناسب كلمة مشهد القصة (rain, sea, night...) للاختيار التلقائي.
  List<AmbientScene> forMood(String mood) =>
      scenes.where((s) => s.moods.contains(mood) && !s.lowRes && !s.categories.contains('fantasy')).toList();

  @visibleForTesting
  void debugSet(List<AmbientScene> list) {
    _scenes
      ..clear()
      ..addEntries(list.map((s) => MapEntry(s.id, s)));
    _loading = Future.value();
  }
}
