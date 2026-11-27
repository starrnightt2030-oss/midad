import 'package:flutter/material.dart';

import '../theme.dart';

/// رموز التصميم الموحّدة لأثير (Design Tokens).
///
/// كل الشاشات والمكونات الجديدة تأخذ قيمها من هنا فقط: الألوان، الخطوط،
/// المسافات، الزوايا، العمق، التدرّجات، الشفافية، مقاسات الأيقونات، ونقاط التجاوب.
/// الألوان المرتبطة بالثيم (المميّز والخلفية) تُقرأ من [MidadColors] حتى تتبع
/// اختيار المستخدم، والهوية الأساسية هي ثيم «أثير» (منتصف الليل + الذهب).

/// ألوان الهوية الأساسية.
class AtheerColors {
  AtheerColors._();

  // اللوحة الأساسية للهوية.
  static const midnight = Color(0xFF090F19);
  static const deepOcean = Color(0xFF182C40);
  static const serenityGreen = Color(0xFF315B50);
  static const champagneGold = Color(0xFFD9BE91);
  static const softIvory = Color(0xFFF0E8DB);

  // درجات مشتقّة.
  static const midnightRaised = Color(0xFF101A28);
  static const midnightHigh = Color(0xFF172436);
  static const goldDeep = Color(0xFFB89868);
  static const goldSoft = Color(0xFFE9D8B8);

  // النصوص فوق الخلفيات الداكنة.
  static const textPrimary = softIvory;
  static Color get textSecondary => softIvory.op(0.72);
  static Color get textTertiary => softIvory.op(0.50);
  static Color get textDisabled => softIvory.op(0.32);

  // الحالات.
  static const success = Color(0xFF7FC4A4);
  static const warning = Color(0xFFE8B86B);
  static const danger = Color(0xFFE88A7F);

  // ألوان مرتبطة بالثيم الحالي.
  static Color get accent => MidadColors.accent;
  static Color get accentDeep => MidadColors.accentDeep;
  static Color get background => MidadColors.ink;
  static Color get backgroundTop => MidadColors.inkTop;
  static Color get surface => MidadColors.surface;
  static Color get surfaceHigh => MidadColors.surfaceHigh;
  static Color get glow => MidadColors.glow;

  /// خط فاصل/حدّ ناعم.
  static Color get hairline => Colors.white.op(AtheerOpacity.hairline);
}

/// مستويات الشفافية المعتمدة.
class AtheerOpacity {
  AtheerOpacity._();
  static const hairline = 0.08;
  static const glassFill = 0.07;
  static const glassFillStrong = 0.12;
  static const glassBorder = 0.12;
  static const scrim = 0.55;
  static const scrimStrong = 0.78;
  static const pressed = 0.85;
  static const disabled = 0.38;
}

/// المسافات (شبكة 4).
class AtheerSpacing {
  AtheerSpacing._();
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 48.0;

  /// الهامش الجانبي للشاشات.
  static const gutter = 22.0;

  /// المسافة بين أقسام الصفحة الرئيسية.
  static const section = 34.0;
}

/// أنصاف أقطار الزوايا.
class AtheerRadius {
  AtheerRadius._();
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get tile => BorderRadius.circular(md);
  static BorderRadius get sheet => const BorderRadius.vertical(top: Radius.circular(xl));
}

/// العمق: ظلال هادئة غير مبالغ فيها.
class AtheerElevation {
  AtheerElevation._();
  static const List<BoxShadow> none = [];

  static List<BoxShadow> get low => [BoxShadow(color: Colors.black.op(0.22), blurRadius: 12, offset: const Offset(0, 4))];
  static List<BoxShadow> get mid => [BoxShadow(color: Colors.black.op(0.30), blurRadius: 22, offset: const Offset(0, 10))];
  static List<BoxShadow> get high => [BoxShadow(color: Colors.black.op(0.38), blurRadius: 36, offset: const Offset(0, 18))];

  /// توهّج خفيف باللون المميّز (للزر الرئيسي فقط).
  static List<BoxShadow> glow([Color? c]) => [BoxShadow(color: (c ?? AtheerColors.accent).op(0.28), blurRadius: 24, offset: const Offset(0, 8))];
}

/// التدرّجات.
class AtheerGradients {
  AtheerGradients._();

  /// خلفية الشاشات (تتبع الثيم).
  static LinearGradient get background => MidadColors.palette.background;

  /// الزر الرئيسي.
  static LinearGradient get accent => MidadColors.palette.button;

  /// ذهبي الهوية (ثابت).
  static const gold = LinearGradient(colors: [AtheerColors.goldSoft, AtheerColors.champagneGold, AtheerColors.goldDeep]);

  /// تظليل الصور من الأسفل حتى يظهر النص واضحًا فوقها.
  static LinearGradient scrimBottom([double strength = 1]) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, AtheerColors.midnight.op(0.35 * strength), AtheerColors.midnight.op(0.88 * strength)],
        stops: const [0.2, 0.55, 1],
      );

  /// تظليل من الأعلى (لشريط الحالة فوق الصور).
  static LinearGradient scrimTop([double strength = 1]) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AtheerColors.midnight.op(0.6 * strength), Colors.transparent],
      );

  /// تدرّج شخصية قسم من لونه.
  static LinearGradient tint(Color c) => LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [c.op(0.55), c.darken(0.25).op(0.15), Colors.transparent],
      );
}

/// مقاسات الأيقونات.
class AtheerIconSize {
  AtheerIconSize._();
  static const xs = 14.0;
  static const sm = 18.0;
  static const md = 22.0;
  static const lg = 28.0;
  static const xl = 36.0;
  static const hero = 56.0;
}

/// نقاط التجاوب حسب عرض الشاشة.
enum AtheerSize { compact, medium, expanded }

class AtheerBreakpoints {
  AtheerBreakpoints._();
  static const compact = 0.0; // الهواتف
  static const medium = 600.0; // الهواتف الكبيرة المفرودة والأجهزة اللوحية الصغيرة
  static const expanded = 900.0; // الأجهزة اللوحية

  static AtheerSize of(double width) => width >= expanded
      ? AtheerSize.expanded
      : width >= medium
          ? AtheerSize.medium
          : AtheerSize.compact;

  static AtheerSize sizeOf(BuildContext context) => of(MediaQuery.sizeOf(context).width);

  /// عدد أعمدة الشبكة المناسب.
  static int columns(BuildContext context, {int compact = 2, int medium = 3, int expanded = 4}) =>
      switch (sizeOf(context)) { AtheerSize.compact => compact, AtheerSize.medium => medium, AtheerSize.expanded => expanded };

  /// أقصى عرض للمحتوى حتى لا يتمدد النص على الشاشات العريضة.
  static const maxContentWidth = 720.0;
}

/// الخطوط: Alexandria للعناوين، IBM Plex Sans Arabic للنصوص، Amiri للحِكم والاقتباسات.
/// كلها مضمّنة داخل التطبيق (assets/fonts) وتعمل بدون إنترنت.
class AtheerType {
  AtheerType._();

  static const display = 'Alexandria';
  static const body = 'IBMPlexSansArabic';
  static const quote = 'Amiri';
  static const callig = 'ArefRuqaa';

  /// في الاختبارات فقط تُستخدم خطوط النظام.
  static String? family(String f) => MidadText.brandFonts ? f : null;

  static TextStyle _s(String fam, double size, FontWeight w, {Color? color, double? height, double? spacing}) => TextStyle(
        fontFamily: family(fam),
        fontSize: size,
        fontWeight: w,
        color: color ?? AtheerColors.textPrimary,
        height: height,
        letterSpacing: spacing,
      );

  // العناوين (Alexandria).
  static TextStyle hero({Color? color}) => _s(display, 34, FontWeight.w700, color: color, height: 1.25);
  static TextStyle h1({Color? color}) => _s(display, 26, FontWeight.w700, color: color, height: 1.3);
  static TextStyle h2({Color? color}) => _s(display, 21, FontWeight.w600, color: color, height: 1.35);
  static TextStyle h3({Color? color}) => _s(display, 17, FontWeight.w600, color: color, height: 1.4);
  static TextStyle overline({Color? color}) => _s(display, 12, FontWeight.w500, color: color ?? AtheerColors.accent, height: 1.4);

  // النصوص (IBM Plex Sans Arabic).
  static TextStyle bodyLarge({Color? color}) => _s(body, 16, FontWeight.w400, color: color, height: 1.7);
  static TextStyle bodyMedium({Color? color}) => _s(body, 14, FontWeight.w400, color: color ?? AtheerColors.textSecondary, height: 1.65);
  static TextStyle bodySmall({Color? color}) => _s(body, 12, FontWeight.w400, color: color ?? AtheerColors.textTertiary, height: 1.5);
  static TextStyle label({Color? color}) => _s(body, 13, FontWeight.w600, color: color, height: 1.3);
  static TextStyle labelSmall({Color? color}) => _s(body, 11, FontWeight.w600, color: color, height: 1.25);
  static TextStyle button({Color? color}) => _s(body, 15, FontWeight.w700, color: color, height: 1.2);

  // الحِكم والاقتباسات (Amiri).
  static TextStyle quoteLarge({Color? color}) => _s(quote, 24, FontWeight.w400, color: color, height: 1.9);
  static TextStyle quoteMedium({Color? color}) => _s(quote, 19, FontWeight.w400, color: color, height: 1.85);
}
