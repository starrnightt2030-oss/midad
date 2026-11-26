import 'dart:io';
import 'dart:ui' as ui;

import 'package:atheer/ambient/ambient_scene_engine.dart';
import 'package:atheer/data/repository.dart';
import 'package:atheer/models.dart';
import 'package:atheer/screens/home_shell.dart';
import 'package:atheer/state/account.dart';
import 'package:atheer/state/downloads.dart';
import 'package:atheer/state/library.dart';
import 'package:atheer/state/player.dart';
import 'package:atheer/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يتحقق أن الواجهة الرئيسية تُبنى بلا أخطاء تخطيط على مقاسات وثيمات مختلفة،
/// فارغة أو مليئة بالحكايات. لو ضُبط HOME_FRAMES تُحفظ لقطات PNG في ذلك المجلد
/// (و FONTS_DIR يشير لملفات خط عربي لتظهر اللقطات بالخط الحقيقي).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MidadText.useGoogleFonts = false;
  final out = Platform.environment['HOME_FRAMES'];
  final fonts = Platform.environment['FONTS_DIR'];

  setUpAll(() async {
    if (fonts == null) return;
    final loader = FontLoader('Roboto');
    for (final f in Directory(fonts).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
      if (!f.path.contains('IBMPlex')) continue;
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
    final icons = File('${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
    }
  });

  Work work(String id, String world, String title, String art, int minutes, {bool premium = false, int chapters = 1}) => Work(
        id: id,
        worldId: world,
        title: title,
        kind: 'قصة',
        description: 'حين يهدأ البحر، يبدأ يوسف رحلته الحقيقية: أن يفهم ما تركته العاصفة في قلبه.',
        art: art,
        narrator: 'أثير',
        minutes: minutes,
        premium: premium,
        chapters: [for (var i = 0; i < chapters; i++) ChapterRef(id: '$id-$i', title: 'الفصل ${i + 1}', script: '')],
      );

  Catalog full() => Catalog(
        version: '1',
        ambience: const [],
        worlds: [
          World(id: 'tales', name: 'عالم الحكايات', short: 'حكايات', tagline: 'قصص هادئة تأخذك إلى النوم', color: const Color(0xFFC8AA78), art: 'lantern'),
          World(id: 'know', name: 'عالم المعرفة', short: 'معرفة', tagline: 'رحلات قصيرة في الكون والبحر', color: const Color(0xFF345653), art: 'mind'),
          World(id: 'morning', name: 'صباحات أثير', short: 'صباح', tagline: '', color: const Color(0xFF192C40), art: 'morning'),
        ],
        works: [
          work('w1', 'tales', 'ما بعد العاصفة', 'lantern', 14, chapters: 3),
          work('w2', 'tales', 'المسافر الذي لم يعد', 'traveler', 22),
          work('w3', 'tales', 'حارس المنارة الأخير', 'storm', 18, premium: true),
          work('w4', 'know', 'أسرار الأعماق', 'deepsea', 11),
          work('w5', 'know', 'خريطة النجوم', 'mind', 9),
          work('w6', 'morning', 'شاي الصباح', 'morning', 6),
        ],
      );

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    if (out == null) return;
    final ro = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await tester.runAsync(() => ro.toImage(pixelRatio: 2));
    final png = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
    Directory(out).createSync(recursive: true);
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  Future<void> render(WidgetTester tester, {required Size size, required AtheerPalette palette, Catalog? catalog, List<String> recent = const [], String? name}) async {
    SharedPreferences.setMockInitialValues({});
    MidadColors.use(palette);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final repo = ContentRepository()..catalog = catalog ?? full();
    final lib = LibraryStore();
    for (final id in recent.reversed) {
      lib.recent.insert(0, id);
    }
    if (recent.isNotEmpty) lib.lastChapter[recent.first] = 1;
    final key = GlobalKey();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: repo),
        ChangeNotifierProvider.value(value: lib),
        ChangeNotifierProvider.value(value: PlayerController(repo)),
        ChangeNotifierProvider.value(value: AccountStore()),
        ChangeNotifierProvider.value(value: DownloadStore(repo)),
        ChangeNotifierProvider.value(value: ThemeController()),
        ChangeNotifierProvider.value(value: AmbientSceneSelector()),
      ],
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeShell(),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    if (name != null) await shot(tester, key, name);
    // نتجاوز مؤقّت فحص التحديثات ثم نفرّغ الشجرة.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
  }

  for (final size in const [Size(360, 740), Size(412, 915), Size(320, 568)]) {
    testWidgets('home builds at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await render(tester, size: size, palette: AtheerPalettes.violet, recent: ['w2', 'w4']);
      await render(tester, size: size, palette: AtheerPalettes.ocean);
      await render(tester, size: size, palette: AtheerPalettes.forest, catalog: Catalog(version: '0', worlds: const [], works: const [], ambience: const []));
    });
  }

  testWidgets('home screenshots', (tester) async {
    if (out == null) return;
    debugDisableShadows = false; // ظلال حقيقية في اللقطات
    addTearDown(() => debugDisableShadows = true);
    const size = Size(390, 844);
    await render(tester, size: size, palette: AtheerPalettes.violet, name: 'violet');
    await render(tester, size: size, palette: AtheerPalettes.violet, recent: ['w2', 'w4'], name: 'violet-resume');
    await render(tester, size: size, palette: AtheerPalettes.ocean, name: 'ocean');
    await render(tester, size: size, palette: AtheerPalettes.forest, name: 'forest');
    await render(tester, size: size, palette: AtheerPalettes.desert, name: 'desert');
    await render(tester, size: size, palette: AtheerPalettes.violet, catalog: Catalog(version: '0', worlds: const [], works: const [], ambience: const []), name: 'empty');
  });
}
