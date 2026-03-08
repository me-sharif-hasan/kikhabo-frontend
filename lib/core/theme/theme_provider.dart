import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

const _kThemeKey = 'app_theme';

class ThemeNotifier extends Notifier<AppThemeType> {
  static const _themeNames = {
    AppThemeType.wiffyGreen: 'wiffyGreen',
    AppThemeType.solarFlare: 'solarFlare',
    AppThemeType.thanos: 'thanos',
    AppThemeType.aurora: 'aurora',
  };

  static const _themeByName = {
    'wiffyGreen': AppThemeType.wiffyGreen,
    'solarFlare': AppThemeType.solarFlare,
    'thanos': AppThemeType.thanos,
    'aurora': AppThemeType.aurora,
  };

  @override
  AppThemeType build() {
    // Load persisted theme asynchronously after initial build.
    _loadSaved();
    return AppThemeType.wiffyGreen;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeKey);
    if (saved != null && _themeByName.containsKey(saved)) {
      final theme = _themeByName[saved]!;
      AppColors.current = AppColors.paletteFor(theme);
      state = theme;
    }
  }

  Future<void> setTheme(AppThemeType theme) async {
    AppColors.current = AppColors.paletteFor(theme);
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, _themeNames[theme]!);
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, AppThemeType>(ThemeNotifier.new);
