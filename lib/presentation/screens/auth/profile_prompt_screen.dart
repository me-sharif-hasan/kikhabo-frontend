import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_card.dart';

class ProfilePromptScreen extends StatelessWidget {
  const ProfilePromptScreen({super.key});

  Future<void> _skipAndGo(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.googleProfileCompletionShownKey, true);
    if (context.mounted) context.go('/dashboard/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient1),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),

                // Icon hero
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.glass,
                    border: Border.all(color: AppColors.glassBorder),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 56,
                    color: AppColors.primaryLight,
                  ),
                ),

                const SizedBox(height: 36),

                Text(
                  'Make Every Meal\nPerfect for You',
                  style: AppTextStyles.headlineMedium.copyWith(height: 1.3),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Our AI chef learns your tastes, health goals, and cultural preferences to suggest meals you\'ll genuinely love — every single day.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 36),

                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: const [
                      _FeatureRow(
                        icon: Icons.restaurant_menu_rounded,
                        color: Color(0xFF4ECDC4),
                        title: 'Personalised meal plans',
                        subtitle: 'Tailored to your cuisine, calorie needs & budget',
                      ),
                      SizedBox(height: 20),
                      _FeatureRow(
                        icon: Icons.monitor_heart_outlined,
                        color: Color(0xFFFF6B6B),
                        title: 'Health-aware suggestions',
                        subtitle: 'Weight, height & age guide the nutritional balance',
                      ),
                      SizedBox(height: 20),
                      _FeatureRow(
                        icon: Icons.mosque_rounded,
                        color: Color(0xFFFFBE0B),
                        title: 'Cultural & religious diet',
                        subtitle: 'Halal, Hindu, Christian — we respect your faith',
                      ),
                      SizedBox(height: 20),
                      _FeatureRow(
                        icon: Icons.flag_rounded,
                        color: Color(0xFF7B2FBE),
                        title: 'Local flavours first',
                        subtitle: 'Ingredients available in your country & region',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                GlassButton(
                  text: 'Complete My Profile',
                  onPressed: () => context.go('/google-profile-completion'),
                  gradient: AppColors.bgGradient2,
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => _skipAndGo(context),
                  child: Text(
                    'Maybe later',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelLarge),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTextStyles.bodySmall.copyWith(height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
