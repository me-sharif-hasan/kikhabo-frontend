import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_color_palette.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/user_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Widget child;

  const DashboardScreen({super.key, required this.child});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    ref.watch(authProvider);
    ref.watch(themeProvider); // rebuild children on theme change
    final user = ref.watch(userProvider).user;

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: AppColors.textPrimary),
          onPressed: () {
            AnalyticsService.instance.logDrawerOpened();
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.palette_outlined, color: AppColors.textPrimary),
            tooltip: 'Change theme',
            onPressed: () => _showThemePicker(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => context.go('/dashboard/profile'),
              child: CircleAvatar(
                backgroundColor: AppColors.glass,
                backgroundImage: user?.profileImageUrl != null
                    ? CachedNetworkImageProvider(user!.profileImageUrl!)
                    : null,
                child: user?.profileImageUrl == null
                    ? Text(
                        user?.firstName?.substring(0, 1).toUpperCase() ?? 'U',
                        style: TextStyle(color: AppColors.primaryLight),
                      )
                    : null,
              ),
            ),
          ),
        ],
        flexibleSpace: GlassStyles.glassContainer(
          child: const SizedBox.expand(),
          blur: 10,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        elevation: 0,
        width: 280,
        child: Column(
          children: [
            // ── GIF header ─────────────────────────────────────────────────
            SizedBox(
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/sidebar_bg.gif', fit: BoxFit.cover),
                  Container(color: Colors.black.withOpacity(0.35)),
                  Positioned(
                    top: 48,
                    right: 16,
                    child: Image.asset('assets/logo.png', width: 52, height: 52),
                  ),
                ],
              ),
            ),
            // ── Nav items on flat surface ───────────────────────────────────
            Expanded(
              child: Container(
                color: AppColors.surface,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildDrawerItem(
                      icon: Icons.home_rounded,
                      title: 'Dashboard',
                      onTap: () => context.go('/dashboard/home'),
                      analyticsId: 'nav_home',
                    ),
                    _buildDrawerItem(
                      icon: Icons.list_alt_rounded,
                      title: 'Meal List',
                      onTap: () => context.go('/dashboard/meals'),
                      analyticsId: 'nav_meals',
                    ),
                    _buildDrawerItem(
                      icon: Icons.people_rounded,
                      title: 'Family Members',
                      onTap: () => context.go('/dashboard/family'),
                      analyticsId: 'nav_family',
                    ),
                    _buildDrawerItem(
                      icon: Icons.settings_rounded,
                      title: 'Preferences',
                      onTap: () => context.go('/dashboard/preferences'),
                      analyticsId: 'nav_preferences',
                    ),
                    _buildDrawerItem(
                      icon: Icons.bar_chart_rounded,
                      title: 'Statistics',
                      onTap: () => context.go('/dashboard/statistics'),
                      analyticsId: 'nav_statistics',
                    ),
                    const Spacer(),
                    Divider(color: AppColors.glassBorder.withOpacity(0.3)),
                    _buildDrawerItem(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      analyticsId: 'nav_logout',
                      onTap: () async {
                        AnalyticsService.instance.logLogout();
                        await ref.read(authProvider.notifier).logout();
                        if (mounted) context.go('/');
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: PopScope(
        canPop: context.canPop(),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            final currentLocation = GoRouterState.of(context).uri.toString();
            if (currentLocation != '/dashboard/home') {
              context.go('/dashboard/home');
            }
          }
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: AppColors.bgGradient2,
          ),
          child: widget.child,
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ThemePickerSheet(),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? analyticsId,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTextStyles.bodyMedium),
      onTap: () {
        _scaffoldKey.currentState?.closeDrawer();
        if (analyticsId != null) {
          AnalyticsService.instance.logDrawerNavigation(analyticsId);
        }
        onTap();
      },
      hoverColor: AppColors.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

// ─── Theme Picker ────────────────────────────────────────────────────────────

class _ThemePickerSheet extends ConsumerWidget {
  const _ThemePickerSheet();

  static const _themes = [
    (type: AppThemeType.wiffyGreen, label: 'Wiffy Green'),
    (type: AppThemeType.solarFlare, label: 'Solar Flare'),
    (type: AppThemeType.thanos, label: 'Thanos'),
    (type: AppThemeType.aurora, label: 'Aurora'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Choose Theme', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),
          for (final t in _themes)
            _ThemeOption(
              type: t.type,
              label: t.label,
              isSelected: current == t.type,
              onTap: () {
                ref.read(themeProvider.notifier).setTheme(t.type);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final AppThemeType type;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.type,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.paletteFor(type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.glass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            _Swatch(color: palette.background),
            _Swatch(color: palette.primary),
            _Swatch(color: palette.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.textPrimary),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  const _Swatch({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 1,
          ),
        ),
      );
}
