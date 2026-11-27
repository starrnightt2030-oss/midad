import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:atheer/ambient/ambient_scene_engine.dart';
import 'package:atheer/models.dart';
import 'package:flutter/material.dart' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ملفات المشاهد', () {
    final manifest = jsonDecode(File('assets/ambient/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    final ids = (manifest['scenes'] as List).map((e) => (e as Map)['id'] as String).toList();

    test('كل مشهد له صورة ومعاينة وقناع وscene.json صالح', () {
      expect(ids.length, greaterThanOrEqualTo(20));
      for (final id in ids) {
        final j = jsonDecode(File('assets/ambient/$id/scene.json').readAsStringSync()) as Map<String, dynamic>;
        final s = AmbientScene.fromJson(j);
        expect(s.id, id);
        expect(File(s.asset).existsSync(), isTrue, reason: s.asset);
        expect(File(s.thumb).existsSync(), isTrue, reason: s.thumb);
        expect(s.masksReady, isTrue, reason: '$id mask');
        expect(File(s.mask!).existsSync(), isTrue, reason: s.mask);
        expect(s.layers, isNotEmpty, reason: '$id has no effects');
        expect(s.layers.length, lessThanOrEqualTo(4));
        expect(s.title, isNot(id), reason: '$id needs an Arabic title');
        expect(s.categories, isNotEmpty);
        for (final c in s.categories) {
          expect(AmbientCategory.all.map((e) => e.id), contains(c));
        }
        // الحركة هادئة: لا إزاحات كبيرة تشوه الصورة.
        for (final l in s.layers) {
          if (l.effect != AmbientEffect.mist && l.effect != AmbientEffect.twinkle && l.effect != AmbientEffect.glow && l.effect != AmbientEffect.rays) {
            expect(l.amount, lessThanOrEqualTo(0.015), reason: '$id ${l.effect}');
          }
          if (l.effect == AmbientEffect.glow) expect(l.amount, lessThanOrEqualTo(0.2), reason: '$id glow must not flash');
        }
      }
    });

    test('المشاهد المؤقتة منخفضة الدقة معلَّمة', () {
      for (final id in ids) {
        final s = AmbientScene.fromJson(jsonDecode(File('assets/ambient/$id/scene.json').readAsStringSync()) as Map<String, dynamic>);
        expect(s.lowRes, s.size.width < 900, reason: id);
      }
    });

    test('مشاهد الخيال في تصنيف منفصل', () {
      for (final id in ['26_volcano_observatory', '27_sky_city']) {
        final s = AmbientScene.fromJson(jsonDecode(File('assets/ambient/$id/scene.json').readAsStringSync()) as Map<String, dynamic>);
        expect(s.categories, ['fantasy']);
      }
    });
  });

  test('تحويل الغلاف يطابق BoxFit.cover', () {
    final tf = CoverTransform.of(const Size(400, 800), const Size(941, 1672), const Offset(0.5, 0.5));
    expect(tf.scale, closeTo(800 / 1672, 1e-9));
    final c = tf.map(const Offset(0.5, 0.5), const Size(941, 1672));
    expect(c.dx, closeTo(200, 1e-6));
    expect(c.dy, closeTo(400, 1e-6));
  });

  test('أوضاع الجودة وتقليل الحركة والخفض التلقائي', () {
    final m = AmbientPerformanceManager.instance..reset();
    expect(m.effective(AmbientQuality.cinematic, reduceMotion: true), AmbientQuality.still);
    expect(m.effective(AmbientQuality.sleep, reduceMotion: true), AmbientQuality.sleep);
    expect(AmbientPerformanceManager.budgetFor(AmbientQuality.cinematic).fps, 30);
    expect(AmbientPerformanceManager.budgetFor(AmbientQuality.still).animated, isFalse);
    m.reportFrameCost(40);
    expect(m.effective(AmbientQuality.cinematic, reduceMotion: false), AmbientQuality.balanced);
    m.reportFrameCost(40);
    expect(m.effective(AmbientQuality.cinematic, reduceMotion: false), AmbientQuality.eco);
    for (var i = 0; i < 4; i++) {
      m.reportFrameCost(8);
    }
    expect(m.effective(AmbientQuality.cinematic, reduceMotion: false), AmbientQuality.balanced);
    m.reset();
  });

  test('الاختيار التلقائي ثابت لكل قصة واليدوي محفوظ', () async {
    SharedPreferences.setMockInitialValues({});
    final reg = AmbientSceneRegistry.instance;
    await reg.load();
    final sel = AmbientSceneSelector();
    await sel.load();
    final a = sel.sceneFor(workId: 'story-1', mood: 'rain');
    expect(a, isNotNull);
    expect(a!.moods, contains('rain'));
    expect(sel.sceneFor(workId: 'story-1', mood: 'rain')!.id, a.id);
    expect(a.lowRes, isFalse);
    sel.choose('05_starry_night');
    expect(sel.sceneFor(workId: 'story-1', mood: 'rain')!.id, '05_starry_night');
    sel.toggleFav('05_starry_night');
    final again = AmbientSceneSelector();
    await again.load();
    expect(again.manual, isTrue);
    expect(again.manualId, '05_starry_night');
    expect(again.isFav('05_starry_night'), isTrue);
  });

  test('الأصوات المحيطية مقفولة افتراضيًا ولها اقتراح لكل مشهد', () async {
    final cat = jsonDecode(File('content/catalog.json').readAsStringSync()) as Map<String, dynamic>;
    final ids = (cat['ambience'] as List).map((e) => (e as Map)['id']).toSet();
    for (final s in ['rain', 'ocean', 'forest', 'fireplace', 'wind', 'stream']) {
      expect(ids, contains(AmbientAudioMixer.sounds[s]), reason: s);
      expect(File('content/ambience/${AmbientAudioMixer.sounds[s]}.m4a').existsSync(), isTrue);
    }
    expect(AmbientAudioMixer.maxVolume, lessThan(1));
  });

  group('موسيقى الخلفية', () {
    final cat = Catalog.fromJson(jsonDecode(File('content/catalog.json').readAsStringSync()) as Map<String, dynamic>);
    final music = cat.ambience.where((a) => a.isMusic).toList();
    Work work(String title, {String kind = '', String desc = ''}) =>
        Work(id: title, worldId: 'w', title: title, kind: kind, description: desc, art: 'storm', narrator: '', minutes: 5, chapters: const []);

    test('أكتر من مقطوعة، وكل ملف موجود في المستودع', () {
      expect(music.length, greaterThanOrEqualTo(6));
      expect(cat.ambience.where((a) => !a.isMusic).length, greaterThanOrEqualTo(10));
      for (final a in cat.ambience) {
        final path = a.file.startsWith('http') ? a.file.split('/main/').last : 'content/${a.file}';
        expect(File(path).existsSync(), isTrue, reason: a.file);
      }
      // مقطوعة واحدة على الأقل داخل التطبيق تعمل بدون إنترنت.
      expect(music.where((a) => !a.file.startsWith('http')), isNotEmpty);
    });

    test('الاختيار حسب نوع القصة', () {
      expect(AmbientAudioMixer.pickMusic(work('حدوتة قبل النوم للأطفال'), cat.ambience)!.moods, anyOf(contains('kids'), contains('sleep')));
      expect(AmbientAudioMixer.pickMusic(work('سر القصر', kind: 'غموض'), cat.ambience)!.id, 'mystery');
      expect(AmbientAudioMixer.pickMusic(work('حكاية من ألف ليلة'), cat.ambience)!.id, 'oriental');
      expect(AmbientAudioMixer.pickMusic(work('عنوان عادي'), cat.ambience)!.id, 'calm');
      // نفس القصة تأخذ نفس الموسيقى دائمًا.
      final w = work('رحلة الأمل');
      expect(AmbientAudioMixer.pickMusic(w, cat.ambience)!.id, AmbientAudioMixer.pickMusic(w, cat.ambience)!.id);
    });
  });

  test('الشيدر مسجل في pubspec', () {
    final pub = File('pubspec.yaml').readAsStringSync();
    expect(pub, contains('shaders/ambient_scene.frag'));
    for (final d in Directory('assets/ambient').listSync().whereType<Directory>()) {
      final name = d.path.split(Platform.pathSeparator).last;
      expect(pub, contains('assets/ambient/$name/'), reason: name);
    }
    expect(Color(0xFF080F1E), const Color(0xFF080F1E));
  });
}
