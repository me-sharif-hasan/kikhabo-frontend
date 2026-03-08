import 'package:flutter/material.dart';
import 'app_color_palette.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  // Named convenience getters
  static ThemeData get wiffyGreen => forType(AppThemeType.wiffyGreen);
  static ThemeData get light => forType(AppThemeType.solarFlare);
  static ThemeData get dark => forType(AppThemeType.thanos);
  static ThemeData get lightMoon => forType(AppThemeType.aurora);

  // Build ThemeData for the given type.
  // NOTE: AppColors.current must already be synced to this type before calling
  // (done in main.dart) so that AppTextStyles reads the correct palette colors.
  static ThemeData forType(AppThemeType type) =>
      _build(AppColors.paletteFor(type));

  static ThemeData _build(AppColorPalette p) => ThemeData(
        useMaterial3: true,
        brightness: p.isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: p.background,
        colorScheme: p.isDark
            ? ColorScheme.dark(
                primary: p.primary,
                secondary: p.accent,
                surface: p.surface,
                error: p.error,
              )
            : ColorScheme.light(
                primary: p.primary,
                secondary: p.accent,
                surface: p.surface,
                error: p.error,
              ),
        textTheme: TextTheme(
          headlineLarge:
              AppTextStyles.headlineLarge.copyWith(color: p.glassText),
          headlineMedium:
              AppTextStyles.headlineMedium.copyWith(color: p.glassText),
          headlineSmall:
              AppTextStyles.headlineSmall.copyWith(color: p.glassText),
          bodyLarge: AppTextStyles.bodyLarge.copyWith(color: p.glassText),
          bodyMedium:
              AppTextStyles.bodyMedium.copyWith(color: p.glassTextSecondary),
          labelLarge: AppTextStyles.labelLarge.copyWith(color: p.glassText),
          labelSmall:
              AppTextStyles.labelSmall.copyWith(color: p.glassTextSecondary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: p.glass.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: p.glassBorder.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: p.glassBorder.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: p.primaryLight),
          ),
          hintStyle: AppTextStyles.bodyMedium
              .copyWith(color: p.glassTextSecondary),
          labelStyle: AppTextStyles.labelLarge,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: p.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: AppTextStyles.labelLarge,
          ),
        ),
      );
}
