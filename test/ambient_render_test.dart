import 'dart:io';
import 'dart:ui' as ui;

import 'package:atheer/ambient/ambient_asset_manager.dart';
import 'package:atheer/ambient/ambient_performance_manager.dart';
import 'package:atheer/ambient/ambient_scene_registry.dart';
import 'package:atheer/ambient/ambient_scene_renderer.dart';
import 'package:atheer/ambient/ambient_shader_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// يرسم المشاهد فعليًا بالشيدر ويحفظ إطارات للمراجعة البصرية لو AMBIENT_FRAMES=1.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['AMBIENT_FRAMES'];
  final only = Platform.environment['AMBIENT_SCENE'];

  testWidgets('render ambient scenes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 732));
    tester.view.physicalSize = const Size(412, 732);
    tester.view.devicePixelRatio = 1;
    await tester.runAsync(() => AmbientSceneRegistry.instance.load());
    final program = await tester.runAsync(() => AmbientShaderManager.instance.program());
    expect(program, isNotNull, reason: 'shader must compile and load');
    final scenes = AmbientSceneRegistry.instance.scenes.where((s) => only == null || s.id == only).toList();
    expect(scenes, isNotEmpty);
    for (final s in scenes) {
      final key = GlobalKey();
      // نسخن الذاكرة المؤقتة خارج الزمن الوهمي (فك ضغط الصور عملية حقيقية).
      await tester.runAsync(() async {
        (await AmbientAssetManager.instance.acquire(s.asset, maxWidth: 412))?.dispose();
        if (s.mask != null) (await AmbientAssetManager.instance.acquire(s.mask!))?.dispose();
      });
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: AmbientSceneView(key: ValueKey(s.id), scene: s, quality: AmbientQuality.cinematic),
      ));
      // تحميل الصور يتم خارج الزمن الوهمي.
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      }
      // AMBIENT_CLIP=ثوانٍ يحفظ إطارات متتالية بمعدل ١٥ إطارًا لصنع فيديو معاينة.
      final clip = double.tryParse(Platform.environment['AMBIENT_CLIP'] ?? '');
      final frames = out == null
          ? [0.0, 0.5]
          : clip != null
              ? [for (var i = 0; i < (clip * 15).round(); i++) i / 15]
              : [0.0, 1.5];
      double last = 0;
      for (final t in frames) {
        await tester.pump(Duration(milliseconds: ((t - last) * 1000).round() + 1));
        last = t;
        if (out == null) continue;
        final ro = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await tester.runAsync(() => ro.toImage());
        final png = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
        Directory(out).createSync(recursive: true);
        File(clip != null ? '$out/${s.id}_${(t * 15).round().toString().padLeft(4, '0')}.png' : '$out/${s.id}_t${t.toStringAsFixed(1)}.png').writeAsBytesSync(png!.buffer.asUint8List());
        img!.dispose();
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
