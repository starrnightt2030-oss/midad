import 'dart:io';
import 'dart:ui' as ui;

import 'package:atheer/data/repository.dart';
import 'package:atheer/design/atheer_design_system.dart';
import 'package:atheer/models.dart';
import 'package:atheer/state/library.dart';
import 'package:atheer/state/player.dart';
import 'package:atheer/theme.dart';
import 'package:atheer/widgets/cover_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يتحقق أن كل مكونات AtheerDesignSystem تُبنى بلا أخطاء تخطيط على مقاسات مختلفة.
/// لو ضُبط DS_FRAMES تُحفظ لقطات PNG، و FONTS_DIR يشير لملفات الخطوط المضمّنة
/// و CATEGORY_IMAGES لصور الأقسام (اختياري).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['DS_FRAMES'];
  final fonts = Platform.environment['FONTS_DIR'];
  final images = Platform.environment['CATEGORY_IMAGES'];
  MidadText.useGoogleFonts = fonts != null;

  setUpAll(() async {
    if (fonts == null) return;
    final families = <String, FontLoader>{};
    for (final f in Directory(fonts).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
      final fam = f.uri.pathSegments.last.split('-').first;
      families.putIfAbsent(fam, () => FontLoader(fam)).addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    for (final l in families.values) {
      await l.load();
    }
    final icons = File('${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
    }
  });

  Work work(String id, String title, String art, int minutes, {bool premium = false}) => Work(
        id: id,
        worldId: 'w',
        title: title,
        kind: 'قصة',
        description: '',
        art: art,
        narrator: 'أثير',
        minutes: minutes,
        premium: premium,
        chapters: [ChapterRef(id: '$id-0', title: 'الفصل ١', script: '')],
      );

  List<File> categoryFiles() {
    if (images == null || !Directory(images).existsSync()) return const [];
    return Directory(images).listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
  }

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    if (out == null) return;
    final ro = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await tester.runAsync(() => ro.toImage(pixelRatio: 2));
    final png = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
    Directory(out).createSync(recursive: true);
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  Widget showcase(List<File> cats) {
    final works = [
      work('a', 'ما بعد العاصفة', 'lantern', 14),
      work('b', 'المسافر الذي لم يعد', 'traveler', 22),
      work('c', 'حارس المنارة الأخير', 'storm', 18, premium: true),
    ];
    const names = ['رسائل من القلب', 'كلمات لها معنى', 'قصص من الواقع', 'من الأرشيف', 'قصص من القرآن'];
    const colors = [Color(0xFF8E5A6B), Color(0xFF4C6A8A), Color(0xFF6B5A44), Color(0xFF5A4E3C), Color(0xFF315B50)];
    Widget cat(int i, {bool large = false}) => AtheerCategoryCard(
          title: names[i],
          subtitle: large ? 'كلمات صادقة تصل إلى القلب قبل الأذن' : null,
          count: [12, 7, 9, 4, 15][i],
          color: colors[i],
          large: large,
          imageProvider: i < cats.length ? MemoryImage(cats[i].readAsBytesSync()) : null,
          onTap: () {},
        );
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AtheerGradients.background),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, 54, AtheerSpacing.gutter, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('مساء الهدوء', style: AtheerType.overline()),
                const SizedBox(height: 6),
                Text('حين تهدأ الحياة... وتتحدث الكلمات', style: AtheerType.h1()),
                const SizedBox(height: AtheerSpacing.lg),
                AtheerSearchBar(onTap: () {}),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.xxl, AtheerSpacing.gutter, 0),
              child: AtheerHeroBanner(
                height: 300,
                overline: 'اختيار أثير اليوم',
                title: 'ما بعد العاصفة',
                subtitle: 'حين يهدأ البحر، يبدأ يوسف رحلته الحقيقية.',
                background: cats.length > 6 ? Image.memory(cats[6].readAsBytesSync(), fit: BoxFit.cover) : const CoverArt(art: 'lantern'),
                actions: [
                  AtheerPrimaryButton(label: 'استمع الآن', icon: Icons.play_arrow_rounded, onPressed: () {}, height: 48),
                  AtheerIconButton(icon: Icons.favorite_border_rounded, tooltip: 'المفضلة', onPressed: () {}),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: AtheerSectionHeader(title: 'أكمل الاستماع', overline: 'من حيث توقفت', onAction: () {})),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 256,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
                itemCount: works.length,
                separatorBuilder: (_, __) => const SizedBox(width: AtheerSpacing.md + 2),
                itemBuilder: (_, i) => AtheerStoryCard(work: works[i], progress: i == 0 ? 0.42 : null, onTap: () {}),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: AtheerSectionHeader(title: 'عوالم أثير', subtitle: 'ستة عشر عالمًا من الحكايات')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 330,
                child: Row(children: [
                  Expanded(flex: 6, child: cat(0, large: true)),
                  const SizedBox(width: AtheerSpacing.md),
                  Expanded(
                    flex: 5,
                    child: Column(children: [
                      Expanded(child: cat(1)),
                      const SizedBox(height: AtheerSpacing.md),
                      Expanded(child: cat(2)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.md, AtheerSpacing.gutter, 0),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 150,
                child: Row(children: [
                  Expanded(child: cat(3)),
                  const SizedBox(width: AtheerSpacing.md),
                  Expanded(child: cat(4)),
                ]),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: AtheerSectionHeader(title: 'رسالة اليوم')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
              child: AtheerGlassCard(
                blur: false,
                padding: const EdgeInsets.all(AtheerSpacing.xxl),
                child: Column(children: [
                  Text('«وما بعد العسر إلا يسرٌ قريب، فاصبر قليلًا تجد الطريق أوسع مما ظننت»', textAlign: TextAlign.center, style: AtheerType.quoteMedium()),
                  const SizedBox(height: AtheerSpacing.md),
                  Text('دقائق من الحكمة', style: AtheerType.bodySmall()),
                ]),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: AtheerSectionHeader(title: 'أثناء التحميل')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
              child: Row(children: [
                const AtheerSkeleton(width: 96, height: 128),
                const SizedBox(width: AtheerSpacing.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    AtheerSkeleton.line(width: 160),
                    SizedBox(height: 10),
                    AtheerSkeleton.line(width: 110),
                    SizedBox(height: 10),
                    AtheerSkeleton.line(width: 70),
                  ]),
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(
            child: AtheerEmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'لا توجد مفضلات بعد',
              message: 'اضغط على القلب في أي قصة لتجدها هنا.',
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]),
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const AtheerMiniPlayer(),
        AtheerBottomNavigation(
          index: 1,
          onTap: (_) {},
          items: const [
            AtheerNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'الرئيسية'),
            AtheerNavItem(icon: Icons.auto_awesome_mosaic_outlined, activeIcon: Icons.auto_awesome_mosaic_rounded, label: 'عوالم أثير'),
            AtheerNavItem(icon: Icons.spa_outlined, activeIcon: Icons.spa_rounded, label: 'سكينة'),
            AtheerNavItem(icon: Icons.bookmarks_outlined, activeIcon: Icons.bookmarks_rounded, label: 'مكتبتي'),
            AtheerNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'رحلتي'),
          ],
        ),
      ]),
    );
  }

  Future<void> render(WidgetTester tester, Size size, {String? name, bool playing = true}) async {
    SharedPreferences.setMockInitialValues({});
    MidadColors.use(AtheerPalettes.atheer);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = ContentRepository();
    final player = PlayerController(repo);
    if (playing) player.work = work('b', 'المسافر الذي لم يعد', 'traveler', 22);
    final cats = categoryFiles();
    if (cats.isNotEmpty) {
      await tester.runAsync(() async {
        for (final f in cats.take(5)) {
          final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
          await codec.getNextFrame();
        }
      });
    }
    final key = GlobalKey();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: repo),
        ChangeNotifierProvider.value(value: LibraryStore()),
        ChangeNotifierProvider.value(value: player),
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
          home: showcase(cats),
        ),
      ),
    ));
    if (cats.isNotEmpty) {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
        await tester.pump();
      }
    }
    await tester.pump(const Duration(milliseconds: 800));
    final ex = tester.takeException();
    if (ex != null) debugPrint("DSERR ${(ex as FlutterError).diagnostics.map((d) => d.toString()).join("\n")}");
    expect(ex, isNull);
    if (name != null) await shot(tester, key, name);
    await tester.pumpWidget(const SizedBox());
  }

  for (final size in const [Size(320, 568), Size(360, 740), Size(412, 915), Size(800, 1280)]) {
    testWidgets('design system builds at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await render(tester, size);
      await render(tester, size, playing: false);
    });
  }

  test('breakpoints', () {
    expect(AtheerBreakpoints.of(360), AtheerSize.compact);
    expect(AtheerBreakpoints.of(700), AtheerSize.medium);
    expect(AtheerBreakpoints.of(1000), AtheerSize.expanded);
  });

  testWidgets('design system screenshots', (tester) async {
    if (out == null) return;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    await render(tester, const Size(390, 1900), name: 'design-system');
  });
}
