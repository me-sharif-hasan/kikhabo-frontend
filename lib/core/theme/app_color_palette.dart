import 'package:flutter/material.dart';

class AppColorPalette {
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color accent;
  final Color accentLight;
  final Color accentDark;
  final Color glass;
  final Color glassBorder;
  final Color glassText;
  final Color glassTextSecondary;
  final Color surface;
  final Color background;
  final Color error;
  final LinearGradient bgGradient1;
  final LinearGradient bgGradient2;
  final bool isDark;

  AppColorPalette({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.glass,
    required this.glassBorder,
    required this.glassText,
    required this.glassTextSecondary,
    required this.surface,
    required this.background,
    required this.error,
    required this.bgGradient1,
    required this.bgGradient2,
    required this.isDark,
  });
}
