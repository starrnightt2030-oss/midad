import 'dart:io';
import 'dart:ui' as ui;

import 'package:atheer/ambient/ambient_asset_manager.dart';
import 'package:atheer/ambient/ambient_scene_engine.dart';
import 'package:atheer/ambient/ambient_shader_manager.dart';
import 'package:atheer/data/repository.dart';
import 'package:atheer/models.dart';
import 'package:atheer/screens/ambient_gallery_screen.dart';
import 'package:atheer/screens/player_screen.dart';
import 'package:atheer/state/library.dart';
import 'package:atheer/state/player.dart';
import 'package:atheer/theme.dart';
import 'package:atheer/widgets/spoken_phrase.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يتحقق أن شاشة التشغيل الجديدة ومكتبة «أجواء أثير» تُبنى بدون أخطاء تخطيط على مقاسات مختلفة،
/// وأن الأدوات تختفي بعد ٨ ثوانٍ من عدم التفاعل وتعود باللمس.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MidadText.useGoogleFonts = false;
  final out = Platform.environment['AMBIENT_FRAMES'];

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    if (out == null) return;
    final ro = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await tester.runAsync(() => ro.toImage());
    final png = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
    Directory(out).createSync(recursive: true);
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  Future<(AmbientSceneSelector, PlayerController, LibraryStore, ContentRepository)> setup(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final sel = AmbientSceneSelector();
    await tester.runAsync(() async {
      await sel.load();
      await AmbientShaderManager.instance.program();
      final s = sel.sceneFor(workId: 'w1', mood: 'night')!;
      (await AmbientAssetManager.instance.acquire(s.asset, maxWidth: 412))?.dispose();
      (await AmbientAssetManager.instance.acquire(s.mask!))?.dispose();
    });
    final repo = ContentRepository();
    final player = PlayerController(repo)
      ..work = Work(
          id: 'w1',
          worldId: 'x',
          title: 'حكاية القمر والبحيرة',
          kind: 'قصة',
          description: '',
          art: 'night',
          narrator: 'أثير',
          minutes: 12,
          chapters: [ChapterRef(id: 'c1', title: 'الفصل الأول', script: '')])
      ..duration = const Duration(minutes: 12)
      ..position = const Duration(minutes: 3)
      // القصة كلها في سطر واحد بلا توقيتات: يجب أن تظهر العبارة المنطوقة فقط.
      ..script = (ChapterScript(lines: [
        ScriptLine(speaker: 'الراوي', text: List.generate(120, (i) => i % 8 == 7 ? 'كلام$i،' : 'كلام$i').join(' ')),
      ], speakerColors: {})
        ..ensureTimings(targetSeconds: 720))
      ..demo = true
      ..wordIndex = 30;
    return (sel, player, LibraryStore(), repo);
  }

  Widget app(Widget child, AmbientSceneSelector sel, PlayerController p, LibraryStore lib, ContentRepository repo, GlobalKey key) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sel),
          ChangeNotifierProvider.value(value: p),
          ChangeNotifierProvider.value(value: lib),
          ChangeNotifierProvider.value(value: repo),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: buildTheme(),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: child,
          ),
        ),
      );

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    testWidgets('player layout ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (sel, p, lib, repo) = await setup(tester);
      final key = GlobalKey();
      await tester.pumpWidget(app(const PlayerScreen(), sel, p, lib, repo, key));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(AmbientSceneView), findsOneWidget);
      expect(find.text('حكاية القمر والبحيرة'), findsNWidgets(2)); // العنوان + طبقة الكلمات
      await shot(tester, key, 'player_${size.width.toInt()}');

      // الأدوات تختفي بعد ٨ ثوانٍ أثناء التشغيل فقط.
      p.playing = true;
      await tester.tap(find.text('حكاية القمر والبحيرة').last, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 9));
      await tester.pump(const Duration(seconds: 2));
      final fade = tester.widget<IgnorePointer>(find.ancestor(of: find.text('تستمع الآن'), matching: find.byType(IgnorePointer)).first);
      expect(fade.ignoring, isTrue);
      // كلمات القصة تبقى ظاهرة بعد اختفاء الأدوات.
      final words = tester.widget<AnimatedOpacity>(find
          .ancestor(of: find.text('حكاية القمر والبحيرة').first, matching: find.byType(AnimatedOpacity))
          .first);
      expect(words.opacity, 1);
      // المعروض هو العبارة المنطوقة الآن فقط، مش نص القصة كله.
      for (final rt in tester.widgetList<RichText>(find.descendant(of: find.byType(SpokenPhrase), matching: find.byType(RichText)))) {
        final shown = rt.text.toPlainText();
        expect(shown, contains('كلام30'));
        expect(shown.split(' ').length, lessThanOrEqualTo(9));
      }
      await shot(tester, key, 'player_hidden_${size.width.toInt()}');
      await tester.tapAt(Offset(size.width / 2, size.height / 2));
      await tester.pump(const Duration(milliseconds: 500));
      final back = tester.widget<IgnorePointer>(find.ancestor(of: find.text('تستمع الآن'), matching: find.byType(IgnorePointer)).first);
      expect(back.ignoring, isFalse);
      p.playing = false;
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('gallery and preview', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (sel, p, lib, repo) = await setup(tester);
    final key = GlobalKey();
    await tester.pumpWidget(app(const AmbientGalleryScreen(), sel, p, lib, repo, key));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('أجواء أثير'), findsOneWidget);
    await shot(tester, key, 'gallery');
    await tester.tap(find.text('المفضلة'));
    await tester.pump();
    expect(find.textContaining('اضغط القلب'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
