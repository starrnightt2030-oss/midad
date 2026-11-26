import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// يحمّل صور الخلفيات والأقنعة عند الطلب فقط، ويحتفظ بعدد صغير منها في الذاكرة،
/// ويتخلص (dispose) من الأقدم. لا تُحمّل كل الخلفيات أبدًا.
class AmbientAssetManager {
  AmbientAssetManager._();
  static final AmbientAssetManager instance = AmbientAssetManager._();

  /// أقصى عدد صور في الذاكرة (خلفية + قناع لمشهدين تقريبًا).
  int capacity = 4;

  final Map<String, _Entry> _cache = {};
  final Map<String, Future<ui.Image?>> _pending = {};

  /// يحمّل صورة أصل (asset) بعرض أقصى [maxWidth] بكسل لتوفير الذاكرة.
  /// يُرجع نسخة (clone) يجب على المستدعي التخلص منها.
  Future<ui.Image?> acquire(String asset, {int? maxWidth}) async {
    final key = '$asset@${maxWidth ?? 0}';
    final hit = _cache[key];
    if (hit != null) {
      hit.used = DateTime.now();
      return hit.image.clone();
    }
    final img = await (_pending[key] ??= _decode(asset, maxWidth).whenComplete(() {
          _pending.remove(key);
        }));
    if (img == null) return null;
    final existing = _cache[key];
    if (existing != null) return existing.image.clone();
    _cache[key] = _Entry(img);
    _evict();
    return img.clone();
  }

  Future<ui.Image?> _decode(String asset, int? maxWidth) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromAsset(asset);
      final codec = await ui.instantiateImageCodecWithSize(buffer, getTargetSize: (w, h) {
        if (maxWidth == null || w <= maxWidth) return ui.TargetImageSize(width: w, height: h);
        return ui.TargetImageSize(width: maxWidth);
      });
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (e) {
      debugPrint('ambient asset $asset failed: $e');
      return null;
    }
  }

  void _evict() {
    while (_cache.length > capacity) {
      final oldest = _cache.entries.reduce((a, b) => a.value.used.isBefore(b.value.used) ? a : b);
      oldest.value.image.dispose();
      _cache.remove(oldest.key);
    }
  }

  /// يفرّغ الذاكرة (مثلًا عند ضغط الذاكرة).
  void clear() {
    for (final e in _cache.values) {
      e.image.dispose();
    }
    _cache.clear();
  }
}

class _Entry {
  final ui.Image image;
  DateTime used = DateTime.now();
  _Entry(this.image);
}
