import 'package:flutter/material.dart';
import 'app_color_palette.dart';

enum AppThemeType { wiffyGreen, solarFlare, thanos, aurora }

class AppColors {
  // --- Current active palette (defaults to Wiffy Green) ---
  static AppColorPalette _current = _wiffyGreen;

  static AppColorPalette get current => _current;
  static set current(AppColorPalette palette) => _current = palette;

  static AppColorPalette paletteFor(AppThemeType type) {
    switch (type) {
      case AppThemeType.wiffyGreen:
        return _wiffyGreen;
      case AppThemeType.solarFlare:
        return _solarFlare;
      case AppThemeType.thanos:
        return _thanos;
      case AppThemeType.aurora:
        return _aurora;
    }
  }

  // ─────────────────────────────────────────
  // Wiffy Green — dark glass, emerald + orange
  // ─────────────────────────────────────────
  static final AppColorPalette _wiffyGreen = AppColorPalette(
    primary: const Color(0xFF047857),
    primaryLight: const Color(0xFF10B981),
    primaryDark: const Color(0xFF065F46),
    accent: const Color(0xFFF97316),
    accentLight: const Color(0xFFFB923C),
    accentDark: const Color(0xFFEA580C),
    glass: const Color(0xFFFFFFFF).withOpacity(0.1),
    glassBorder: const Color(0xFFFFFFFF).withOpacity(0.2),
    glassText: const Color(0xFFFFFFFF).withOpacity(0.9),
    glassTextSecondary: const Color(0xFFFFFFFF).withOpacity(0.7),
    surface: const Color(0xFF1F2937),
    background: const Color(0xFF111827),
    error: const Color(0xFFEF4444),
    bgGradient1: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1F2937), Color(0xFF111827)],
    ),
    bgGradient2: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF047857), Color(0xFF0D9488)],
    ),
    isDark: true,
  );

  // ─────────────────────────────────────────
  // Solar Flare — pure white, crimson red + golden yellow
  // Luminous light mode: bright glowing warm spectrum, not dark/burnt
  // ─────────────────────────────────────────
  static final AppColorPalette _solarFlare = AppColorPalette(
    primary: const Color(0xFFFF1744),       // vivid rose-red — bright, not dark
    primaryLight: const Color(0xFFFF0035),  // hot pink-red
    primaryDark: const Color(0xFFCC0033),   // deep red
    accent: const Color(0xFFFFD600),        // electric yellow — almost neon
    accentLight: const Color(0xFFFFEA40),   // bright lemon
    accentDark: const Color(0xFFFFC200),    // deep golden yellow
    glass: const Color(0xFFFF1744).withOpacity(0.06),
    glassBorder: const Color(0xFFFF1744).withOpacity(0.15),
    glassText: const Color(0xFF1A0008),     // near-black warm tint
    glassTextSecondary: const Color(0xFFBE123C), // deep rose — readable on white
    surface: const Color(0xFFFFFFFF),
    background: const Color(0xFFFFFFFF),    // pure white — let the colors glow
    error: const Color(0xFFEF4444),
    bgGradient1: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFFFFF), Color(0xFFFFF5F7)], // white → barely-there rose
    ),
    bgGradient2: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFE4E8), Color(0xFFFFF3D1)], // soft rose → warm cream
    ),
    isDark: false,
  );

  // ─────────────────────────────────────────
  // Thanos — near-black, purple + pink
  // ─────────────────────────────────────────
  static final AppColorPalette _thanos = AppColorPalette(
    primary: const Color(0xFF6366F1),
    primaryLight: const Color(0xFF818CF8),
    primaryDark: const Color(0xFF4F46E5),
    accent: const Color(0xFFEC4899),
    accentLight: const Color(0xFFF472B6),
    accentDark: const Color(0xFFDB2777),
    glass: const Color(0xFFFFFFFF).withOpacity(0.08),
    glassBorder: const Color(0xFFFFFFFF).withOpacity(0.15),
    glassText: const Color(0xFFFFFFFF).withOpacity(0.92),
    glassTextSecondary: const Color(0xFFFFFFFF).withOpacity(0.60),
    surface: const Color(0xFF16161E),
    background: const Color(0xFF08090E),
    error: const Color(0xFFEF4444),
    bgGradient1: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF16161E), Color(0xFF08090E)],
    ),
    bgGradient2: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0D0E1A), Color(0xFF12131F)],
    ),
    isDark: true,
  );

  // ─────────────────────────────────────────
  // Aurora — deep slate, electric cyan + rose gold
  // Dark theme with an ethereal northern-lights feel
  // ─────────────────────────────────────────
  static final AppColorPalette _aurora = AppColorPalette(
    primary: const Color(0xFF00C9B1),       // electric teal-cyan
    primaryLight: const Color(0xFF2DEDD8),  // bright aqua
    primaryDark: const Color(0xFF009E8A),   // deep teal
    accent: const Color(0xFFFFAA5B),        // warm rose-gold / amber
    accentLight: const Color(0xFFFFCA8A),   // soft gold
    accentDark: const Color(0xFFE8862A),    // burnt amber
    glass: const Color(0xFF00C9B1).withOpacity(0.10),
    glassBorder: const Color(0xFF00C9B1).withOpacity(0.22),
    glassText: const Color(0xFFE8F8F6),
    glassTextSecondary: const Color(0xFFE8F8F6).withOpacity(0.60),
    surface: const Color(0xFF141E26),       // dark slate-teal
    background: const Color(0xFF0A1219),    // near-black with cool tint
    error: const Color(0xFFFF6B6B),
    bgGradient1: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF141E26), Color(0xFF0A1219)],
    ),
    bgGradient2: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0A2420), Color(0xFF0A1219)], // deep teal-black gradient
    ),
    isDark: true,
  );

  // ─────────────────────────────────────────
  // Backward-compatible static getters
  // All delegate to the active palette so existing code keeps working.
  // ─────────────────────────────────────────
  static Color get primary => _current.primary;
  static Color get primaryLight => _current.primaryLight;
  static Color get primaryDark => _current.primaryDark;
  static Color get accent => _current.accent;
  static Color get accentLight => _current.accentLight;
  static Color get accentDark => _current.accentDark;
  static Color get glass => _current.glass;
  static Color get glassBorder => _current.glassBorder;
  static Color get glassText => _current.glassText;
  static Color get glassTextSecondary => _current.glassTextSecondary;
  static Color get surface => _current.surface;
  static Color get background => _current.background;
  static Color get error => _current.error;
  static LinearGradient get bgGradient1 => _current.bgGradient1;
  static LinearGradient get bgGradient2 => _current.bgGradient2;

  // Aliases
  static Color get textPrimary => _current.glassText;
  static Color get textSecondary => _current.glassTextSecondary;
}