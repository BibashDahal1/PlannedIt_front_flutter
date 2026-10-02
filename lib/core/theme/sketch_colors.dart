import 'package:flutter/material.dart';

class SketchColors {
  SketchColors._();

  static bool _isDark = false;
  static void sync(bool isDark) => _isDark = isDark;

  static Color get ink =>
      _isDark ? const Color(0xFFEDEAE2) : const Color(0xFF2B2B2B);
  static Color get inkFaint =>
      _isDark ? const Color(0xFFB7B0A0) : const Color(0xFF8A8578);
  static Color get paper =>
      _isDark ? const Color(0xFF1E1C18) : const Color(0xFFF6F3EC);
  static Color get paperFleck =>
      _isDark ? const Color(0xFF38342C) : const Color(0xFFD2C8B2);
  static Color get danger =>
      _isDark ? const Color(0xFFD08870) : const Color(0xFF8A4A3A);
}
