import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sketch_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final base = GoogleFonts.kalamTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SketchColors.ink,
        brightness: brightness,
        surface: SketchColors.paper,
      ),
      textTheme: base.apply(
        bodyColor: SketchColors.ink,
        displayColor: SketchColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: SketchColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.kalam(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: SketchColors.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintStyle: GoogleFonts.kalam(
          color: SketchColors.inkFaint,
          fontSize: 16,
        ),
      ),
    );
  }

  static TextStyle heading({
    double size = 26,
    FontWeight weight = FontWeight.w700,
  }) => GoogleFonts.caveat(
    fontSize: size,
    fontWeight: weight,
    color: SketchColors.ink,
  );
}
