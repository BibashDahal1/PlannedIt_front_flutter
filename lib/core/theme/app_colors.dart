import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(
    0xFF4F46E5,
  ); // indigo — buttons, active states
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color primarySoft = Color(
    0xFFEEF0FD,
  ); // light indigo tint for icon chips/badges

  static const Color background = Color(0xFFF5F6FA); // app background
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE5E7EB);

  static const Color textPrimary = Color(0xFF14142B);
  static const Color textSecondary = Color(0xFF6E7191);

  static const Color success = Color(0xFF1E8A6E);
  static const Color danger = Color(0xFFD64545);
  static const Color warning = Color(0xFFF2A93B);

  // Trust badge tiers
  static const Color tierBasic = Color(0xFF9CA3AF);
  static const Color tierSocialVerified = Color(0xFF3B82F6);
  static const Color tierFullyVerified = Color(0xFF1E8A6E);
}
