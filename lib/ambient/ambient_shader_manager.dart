import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// يحمّل برنامج الشيدر مرة واحدة فقط ويعيد استخدامه لكل المشاهد.
/// لو فشل (جهاز لا يدعم، أو خطأ ترجمة) يرجع null فيعمل المحرك بخلفية ثابتة.
class AmbientShaderManager {
  AmbientShaderManager._();
  static final AmbientShaderManager instance = AmbientShaderManager._();

  static const asset = 'shaders/ambient_scene.frag';

  Future<ui.FragmentProgram?>? _program;
  bool failed = false;

  Future<ui.FragmentProgram?> program() => _program ??= _load();

  Future<ui.FragmentProgram?> _load() async {
    try {
      return await ui.FragmentProgram.fromAsset(asset);
    } catch (e) {
      failed = true;
      debugPrint('ambient shader unavailable, static fallback: $e');
      return null;
    }
  }
}
