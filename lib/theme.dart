import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MidadColors {
  static const ink = Color(0xFF070B16);
  static const surface = Color(0xFF121A2B);
  static const paper = Color(0xFFF3ECDF);
  static const paperInk = Color(0xFF2B2620);
  static const saffron = Color(0xFFE8B04B);
  static const muted = Color(0xFFA6A9B6);
}

extension ColorAlpha on Color {
  /// بديل آمن لـ withOpacity يعمل على كل إصدارات Flutter.
  Color op(double a) => withAlpha((a.clamp(0.0, 1.0) * 255).round());

  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}

Color parseHex(String? hex, [Color fallback = MidadColors.saffron]) {
  if (hex == null || hex.isEmpty) return fallback;
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

class MidadText {
  static TextStyle ui({double size = 14, FontWeight weight = FontWeight.w500, Color color = Colors.white, double? height}) =>
      GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color, height: height);

  static TextStyle title({double size = 22, Color color = Colors.white, double? height}) =>
      GoogleFonts.reemKufi(fontSize: size, fontWeight: FontWeight.w700, color: color, height: height);

  static TextStyle book({double size = 20, Color color = Colors.white, FontWeight weight = FontWeight.w400, double height = 1.9}) =>
      GoogleFonts.amiri(fontSize: size, fontWeight: weight, color: color, height: height);

  static TextStyle callig({double size = 40, Color color = Colors.white}) =>
      GoogleFonts.arefRuqaa(fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.25);
}

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: MidadColors.ink,
    colorScheme: base.colorScheme.copyWith(primary: MidadColors.saffron, secondary: MidadColors.saffron, surface: MidadColors.surface),
    textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    ),
  );
}
