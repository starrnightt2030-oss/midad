import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// لوحة ألوان ثيم واحد. كل الثيمات داكنة لأن التطبيق للّيل والاسترخاء.
class AtheerPalette {
  final String id;
  final String name;
  final Color bgTop; // أعلى التدرّج
  final Color bg; // الخلفية الأساسية (أسفل التدرّج)
  final Color surface; // البطاقات والقوائم
  final Color surfaceHigh; // عناصر مرفوعة (شريط التنقّل، الأزرار)
  final Color accent; // اللون المميّز
  final Color accentDeep; // الطرف الثاني لتدرّج الأزرار
  final Color glow; // توهّج الخلفية

  const AtheerPalette({
    required this.id,
    required this.name,
    required this.bgTop,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.accent,
    required this.accentDeep,
    required this.glow,
  });

  LinearGradient get background => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bgTop, bg]);
  LinearGradient get button => LinearGradient(colors: [accent, accentDeep]);
}

class AtheerPalettes {
  /// هوية أثير الأساسية: منتصف الليل، المحيط العميق، أخضر السكينة، والذهب الشمبانيا.
  static const atheer = AtheerPalette(
    id: 'atheer',
    name: 'ليل أثير',
    bgTop: Color(0xFF182C40), // Deep Ocean
    bg: Color(0xFF090F19), // Midnight
    surface: Color(0xFF101A28),
    surfaceHigh: Color(0xFF172436),
    accent: Color(0xFFD9BE91), // Champagne Gold
    accentDeep: Color(0xFFB89868),
    glow: Color(0xFF315B50), // Serenity Green
  );
  static const violet = AtheerPalette(
    id: 'violet',
    name: 'ليل بنفسجي',
    bgTop: Color(0xFF2D1B4E),
    bg: Color(0xFF130B22),
    surface: Color(0xFF22163A),
    surfaceHigh: Color(0xFF2E2050),
    accent: Color(0xFFB794F6),
    accentDeep: Color(0xFF8B5CF6),
    glow: Color(0xFF7C4DDB),
  );
  static const ocean = AtheerPalette(
    id: 'ocean',
    name: 'محيط عميق',
    bgTop: Color(0xFF12324A),
    bg: Color(0xFF07131F),
    surface: Color(0xFF0F2436),
    surfaceHigh: Color(0xFF173149),
    accent: Color(0xFF5ED3E0),
    accentDeep: Color(0xFF2B9FC0),
    glow: Color(0xFF1E7FA8),
  );
  static const forest = AtheerPalette(
    id: 'forest',
    name: 'غابة الغسق',
    bgTop: Color(0xFF1B3A2F),
    bg: Color(0xFF0A1612),
    surface: Color(0xFF142A22),
    surfaceHigh: Color(0xFF1D392E),
    accent: Color(0xFF8FDCB0),
    accentDeep: Color(0xFF4FAF7F),
    glow: Color(0xFF2F8A60),
  );
  static const desert = AtheerPalette(
    id: 'desert',
    name: 'صحراء الفجر',
    bgTop: Color(0xFF3A2518),
    bg: Color(0xFF150D08),
    surface: Color(0xFF2A1C13),
    surfaceHigh: Color(0xFF3A281B),
    accent: Color(0xFFF0B35A),
    accentDeep: Color(0xFFD9822B),
    glow: Color(0xFFB8692A),
  );

  static const all = [atheer, violet, ocean, forest, desert];

  static AtheerPalette byId(String? id) => all.firstWhere((p) => p.id == id, orElse: () => atheer);
}

/// ألوان الثيم الحالي. تُقرأ من أي مكان، وتتغيّر فورًا عند تغيير الثيم.
class MidadColors {
  static AtheerPalette _p = AtheerPalettes.atheer;
  static AtheerPalette get palette => _p;
  static void use(AtheerPalette p) => _p = p;

  static Color get ink => _p.bg;
  static Color get inkTop => _p.bgTop;
  static Color get surface => _p.surface;
  static Color get surfaceHigh => _p.surfaceHigh;
  static Color get saffron => _p.accent; // الاسم القديم للّون المميّز
  static Color get accent => _p.accent;
  static Color get accentDeep => _p.accentDeep;
  static Color get glow => _p.glow;

  // ورق القراءة: ثابت في كل الثيمات.
  static const paper = Color(0xFFF0E8DB); // Soft Ivory
  static const paperInk = Color(0xFF2B2620);
  static const muted = Color(0xFFA6A9B6);
}

/// يحفظ الثيم المختار ويبلّغ التطبيق عند تغييره.
class ThemeController extends ChangeNotifier {
  static const _key = 'atheer_theme';
  AtheerPalette get palette => MidadColors.palette;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      MidadColors.use(AtheerPalettes.byId(p.getString(_key)));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> set(AtheerPalette p) async {
    if (p.id == palette.id) return;
    MidadColors.use(p);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, p.id);
    } catch (_) {}
  }
}

extension ColorAlpha on Color {
  /// بديل آمن لـ withOpacity يعمل على كل إصدارات Flutter.
  Color op(double a) => withAlpha((a.clamp(0.0, 1.0) * 255).round());

  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}

Color parseHex(String? hex, [Color? fallback]) {
  final fb = fallback ?? MidadColors.accent;
  if (hex == null || hex.isEmpty) return fb;
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fb : Color(v);
}

/// خطوط التطبيق، كلها مضمّنة داخل التطبيق (assets/fonts) وتعمل بدون إنترنت:
/// Alexandria للعناوين، IBM Plex Sans Arabic للنصوص، Amiri للقراءة والحِكم، Aref Ruqaa للخط اليدوي.
class MidadText {
  /// في الاختبارات فقط: خطوط النظام بدل الخطوط المضمّنة.
  /// (الاسم قديم وبقي كما هو حتى لا تنكسر الاختبارات.)
  @visibleForTesting
  static bool useGoogleFonts = true;

  /// هل تُستخدم الخطوط المضمّنة (دائمًا خارج الاختبارات).
  static bool get brandFonts => useGoogleFonts;

  static String? _f(String family) => useGoogleFonts ? family : null;

  static TextStyle ui({double size = 14, FontWeight weight = FontWeight.w500, Color color = Colors.white, double? height}) =>
      TextStyle(fontFamily: _f('IBMPlexSansArabic'), fontSize: size, fontWeight: weight, color: color, height: height);

  static TextStyle title({double size = 22, Color color = Colors.white, double? height}) =>
      TextStyle(fontFamily: _f('Alexandria'), fontSize: size, fontWeight: FontWeight.w600, color: color, height: height);

  static TextStyle book({double size = 20, Color color = Colors.white, FontWeight weight = FontWeight.w400, double height = 1.9}) =>
      TextStyle(fontFamily: _f('Amiri'), fontSize: size, fontWeight: weight, color: color, height: height);

  static TextStyle callig({double size = 40, Color color = Colors.white}) =>
      TextStyle(fontFamily: _f('ArefRuqaa'), fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.25);
}

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: MidadText.useGoogleFonts ? 'IBMPlexSansArabic' : null);
  return base.copyWith(
    scaffoldBackgroundColor: MidadColors.ink,
    colorScheme: base.colorScheme.copyWith(
      primary: MidadColors.accent,
      secondary: MidadColors.accent,
      surface: MidadColors.surface,
      onPrimary: MidadColors.ink,
    ),
    textTheme: MidadText.useGoogleFonts ? base.textTheme.apply(fontFamily: 'IBMPlexSansArabic') : base.textTheme,
    snackBarTheme: SnackBarThemeData(backgroundColor: MidadColors.surfaceHigh, behavior: SnackBarBehavior.floating),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: MidadColors.accent,
      thumbColor: MidadColors.accent,
      inactiveTrackColor: Colors.white24,
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    ),
  );
}

/// يعيد بناء الشجرة كلها (بعد تغيير الثيم) بدون فقدان الشاشة الحالية.
void rebuildAllChildren(BuildContext context) {
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  (context as Element).visitChildren(mark);
}
