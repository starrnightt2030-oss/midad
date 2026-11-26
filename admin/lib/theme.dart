import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kBg = Color(0xFF130B22);
const kSurface = Color(0xFF22163A);
const kSurfaceHigh = Color(0xFF2E2050);
const kAccent = Color(0xFFB794F6);
const kAccentDeep = Color(0xFF8B5CF6);

ThemeData adminTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, colorSchemeSeed: kAccentDeep);
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    colorScheme: base.colorScheme.copyWith(primary: kAccent, surface: kSurface, onPrimary: kBg, secondary: kAccent),
    textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme),
    cardTheme: const CardThemeData(color: kSurface, elevation: 0, margin: EdgeInsets.zero),
    dialogTheme: const DialogThemeData(backgroundColor: kSurface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, minimumSize: const Size(0, 48)),
    ),
  );
}
