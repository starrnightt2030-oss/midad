import 'dart:io';
import 'dart:ui' as ui;

import 'package:atheer/ambient/ambient_scene_engine.dart';
import 'package:atheer/data/repository.dart';
import 'package:atheer/models.dart';
import 'package:atheer/screens/world_screen.dart';
import 'package:atheer/screens/worlds_screen.dart';
import 'package:atheer/state/account.dart';
import 'package:atheer/state/downloads.dart';
import 'package:atheer/state/library.dart';
import 'package:atheer/state/player.dart';
import 'package:atheer/theme.dart';
import 'package:atheer/widgets/story_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «عوالم أثير» وصفحة القسم: تُبنى بلا أخطاء تخطيط على مقاسات مختلفة.
/// لو ضُبط WORLD_FRAMES تُحفظ لقطات PNG في ذلك المجلد (و FONTS_DIR لخط عربي حقيقي).
/// القصص هنا بيانات اختبار فقط.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MidadText.useGoogleFonts = false;
  final out = Platform.environment['WORLD_FRAMES'];
  final fonts = Platform.environment['FONTS_DIR'];

  setUpAll(() async {
    if (fonts == null) return;
    final loader = FontLoader('Roboto');
    for (final f in Directory(fonts).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
    final icons = File('${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
    }
  });

  final worlds = [
    World(
        id: 'heartfelt_messages',
        name: 'رسائل من القلب',
        short: 'رسائل من القلب',
        tagline: 'كلمات تصل إلى أعماق قلبك',
        description: 'رسائل إنسانية مؤثرة، ومواساة، وكلمات يحتاج الإنسان إلى سماعها في أوقات مختلفة من حياته.',
        color: const Color(0xFFE8A0A8),
        color2: const Color(0xFFD4AF6A),
        art: 'storm'),
    World(
        id: 'meaningful_words',
        name: 'كلمات لها معنى',
        short: 'كلمات لها معنى',
        tagline: 'كلمات قليلة... ومعانٍ لا تنتهي',
        description: 'حكم ومواعظ وتأملات تحمل معاني عميقة ودروسًا مستفادة من الحياة.',
        color: const Color(0xFFE9DCC0),
        color2: const Color(0xFF8B5E3C),
        art: 'storm'),
    World(
        id: 'real_stories',
        name: 'قصص من الواقع',
        short: 'قصص من الواقع',
        tagline: 'حكايات عاشها أناس مثلنا',
        description: 'قصص حقيقية وتجارب إنسانية ومواقف واقعية تحمل العبرة والأمل والدروس المستفادة.',
        color: const Color(0xFFE3A35B),
        color2: const Color(0xFF7A3E2B),
        art: 'storm'),
    World(
        id: 'from_the_archive',
        name: 'من الأرشيف',
        short: 'من الأرشيف',
        tagline: 'حكايات طواها الزمن ولم ينسها الأثر',
        description: 'حكايات من الماضي وأحداث تاريخية وقصص منسية تستحق أن تُروى من جديد.',
        color: const Color(0xFFC08A52),
        color2: const Color(0xFF6B4226),
        art: 'storm'),
    World(
        id: 'quran_stories',
        name: 'قصص من القرآن',
        short: 'قصص من القرآن',
        tagline: 'قصص خالدة وعبر لا تنتهي',
        description: 'القصص الواردة في القرآن الكريم بأسلوب سردي مؤثر، مع الالتزام بالمصادر الصحيحة واستخلاص العبر والدروس.',
        color: const Color(0xFF3FA37A),
        color2: const Color(0xFFD4AF37),
        art: 'storm'),
    World(
        id: 'biographies',
        name: 'سيرة ومسيرة',
        short: 'سيرة ومسيرة',
        tagline: 'حياة تُروى... وأثر يبقى',
        description: 'سير الأنبياء والصحابة والعلماء والشخصيات المؤثرة وأصحاب الإنجازات، مع توثيق الروايات.',
        color: const Color(0xFFC9925A),
        color2: const Color(0xFF5E4330),
        art: 'storm'),
    World(
        id: 'bedtime_stories',
        name: 'قبل أن تنام',
        short: 'قبل أن تنام',
        tagline: 'دع ضجيج اليوم يرحل',
        description: 'قصص هادئة وحكايات مسموعة وكلمات مطمئنة تساعد على الاسترخاء والاستعداد للنوم.',
        color: const Color(0xFFA58CF0),
        color2: const Color(0xFF1C2457),
        art: 'storm'),
    World(
        id: 'self_discovery',
        name: 'رحلة إلى الذات',
        short: 'رحلة إلى الذات',
        tagline: 'اكتشف نفسك من جديد',
        description: 'تنمية الذات والثقة بالنفس وفهم المشاعر وتطوير الشخصية والتعامل مع ضغوط الحياة.',
        color: const Color(0xFF8FD694),
        color2: const Color(0xFF2F5D3A),
        art: 'storm'),
    World(
        id: 'tranquility',
        name: 'طمأنينة',
        short: 'طمأنينة',
        tagline: 'هنا يجد قلبك بعض السلام',
        description: 'كلمات عن السكينة والصبر والرضا والتوكل والتعامل مع الحزن والقلق وضغوط الحياة.',
        color: const Color(0xFF5ED3E0),
        color2: const Color(0xFF1E6F8F),
        art: 'storm'),
    World(
        id: 'life_lessons',
        name: 'علمتني الحياة',
        short: 'علمتني الحياة',
        tagline: 'لكل تجربة درس... ولكل درس أثر',
        description: 'دروس الحياة والتجارب والمواقف الإنسانية التي تغير نظرة الإنسان إلى العالم.',
        color: const Color(0xFFF0B35A),
        color2: const Color(0xFF8A4B12),
        art: 'storm'),
    World(
        id: 'hope_after_hardship',
        name: 'بعد العسر يسر',
        short: 'بعد العسر يسر',
        tagline: 'مهما طال الليل... سيأتي الصباح',
        description: 'قصص تجاوز المحن والابتلاءات والفشل والعودة إلى الحياة بأمل جديد.',
        color: const Color(0xFFF5C26B),
        color2: const Color(0xFF2A1A12),
        art: 'storm'),
    World(
        id: 'wisdom_minutes',
        name: 'دقائق من الحكمة',
        short: 'دقائق من الحكمة',
        tagline: 'دقائق قليلة قد تغير الكثير',
        description: 'حكم وخواطر ومواعظ صوتية قصيرة تتراوح مدتها بين دقيقة وخمس دقائق.',
        color: const Color(0xFFD4AF37),
        color2: const Color(0xFF121212),
        art: 'storm'),
    World(
        id: 'between_hearts',
        name: 'بين القلوب',
        short: 'بين القلوب',
        tagline: 'لأن أجمل ما في الحياة هو الإنسان',
        description: 'العلاقات الإنسانية والزواج والصداقة والأسرة والحب والتسامح وفهم الآخرين.',
        color: const Color(0xFFE7A6B5),
        color2: const Color(0xFF7D8B52),
        art: 'storm'),
    World(
        id: 'nostalgic_tales',
        name: 'حكايات زمان',
        short: 'حكايات زمان',
        tagline: 'رحلة إلى زمن لا يغيب عن الذاكرة',
        description: 'حكايات التراث الشعبي والذكريات الجميلة والحياة في الزمن القديم.',
        color: const Color(0xFFE2B77E),
        color2: const Color(0xFF5B4A3A),
        art: 'storm'),
    World(
        id: 'turning_point',
        name: 'نقطة تحول',
        short: 'نقطة تحول',
        tagline: 'لحظة واحدة قد تغير مسار الحياة',
        description: 'قصص القرارات المصيرية والمواقف التي غيرت حياة أصحابها بالكامل.',
        color: const Color(0xFF4FC08D),
        color2: const Color(0xFFD4AF37),
        art: 'storm'),
    World(
        id: 'spiritual_nourishment',
        name: 'زاد الروح',
        short: 'زاد الروح',
        tagline: 'ما يحيي القلب ويغذي الروح',
        description: 'خواطر إيمانية ومواعظ وتدبر ومعانٍ روحانية تقرب الإنسان من الله.',
        color: const Color(0xFFE9DFC7),
        color2: const Color(0xFF2E7D5B),
        art: 'storm'),
  ];

  var n = 0;
  Work work(List<String> ws, String title, int minutes, {int plays = 0, bool premium = false}) => Work(
        id: 'w${++n}',
        worldId: ws.first,
        worldIds: ws,
        title: title,
        kind: 'قصة',
        description: 'وصف تجريبي',
        art: 'storm',
        narrator: 'أثير',
        minutes: minutes,
        plays: plays,
        premium: premium,
        added: DateTime(2026, 11, n),
        chapters: const [],
      );

  Catalog catalog() {
    n = 0;
    return Catalog(
        version: '1',
        ambience: const [],
        worlds: worlds,
        works: [
          work(['bedtime_stories'], 'حكاية القمر الصغير', 12, plays: 40),
          work(['bedtime_stories', 'tranquility'], 'نوم هادئ', 8, plays: 95),
          work(['bedtime_stories'], 'المسافر الأخير', 22, premium: true),
          work(['bedtime_stories'], 'بيت على البحر', 4, plays: 12),
          work(['tranquility'], 'سكينة', 5),
          work(['heartfelt_messages'], 'رسالة إليك', 3),
        ]);
  }

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    if (out == null) return;
    final ro = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await tester.runAsync(() => ro.toImage(pixelRatio: 2));
    final png = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
    Directory(out).createSync(recursive: true);
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump(const Duration(milliseconds: 600));
    }
  }

  Future<void> render(WidgetTester tester, Widget page, {required Size size, String? name, Future<void> Function()? then}) async {
    SharedPreferences.setMockInitialValues({});
    MidadColors.use(AtheerPalettes.violet);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = ContentRepository()..catalog = catalog();
    final key = GlobalKey();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: repo),
        ChangeNotifierProvider.value(value: LibraryStore()),
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
          home: page,
        ),
      ),
    ));
    await settle(tester);
    expect(tester.takeException(), isNull);
    if (name != null) await shot(tester, key, name);
    if (then != null) {
      await then();
      await settle(tester);
      expect(tester.takeException(), isNull);
      if (name != null) await shot(tester, key, '$name-2');
    }
    await tester.pumpWidget(const SizedBox());
  }

  const grid = Scaffold(body: AtheerBackground(child: WorldsScreen()));

  for (final size in const [Size(320, 568), Size(360, 740), Size(412, 915), Size(800, 1280)]) {
    testWidgets('worlds build at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await render(tester, grid, size: size);
      await render(tester, const WorldScreen(worldId: 'bedtime_stories'), size: size);
      await render(tester, const WorldScreen(worldId: 'quran_stories'), size: size);
    });
  }

  testWidgets('worlds screenshots', (tester) async {
    if (out == null) return;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    const size = Size(390, 844);
    await render(tester, grid, size: size, name: 'worlds', then: () async {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    });
    await render(tester, const WorldScreen(worldId: 'bedtime_stories'), size: size, name: 'world-bedtime', then: () async {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -560));
    });
    await render(tester, const WorldScreen(worldId: 'quran_stories'), size: size, name: 'world-soon');
  });
}
