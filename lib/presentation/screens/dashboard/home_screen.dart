import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/api_error_handler.dart';
import '../../../data/models/meal.dart';
import '../../../domain/providers/meal_provider.dart';
import '../../../domain/providers/ingredient_scan_provider.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_slider.dart';
import 'package:dio/dio.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Meal Planning State
  double _spicyRating = 5.0;
  double _saltRating = 5.0;
  double _priceRating = 3.0;
  double _daysCount = 1.0;
  double _mealsPerDay = 3.0;

  // Generation progress
  bool _isGenerating = false;
  double _progress = 0.0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('home');
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startProgressTimer() {
    _progress = 0.0;
    _progressTimer?.cancel();
    // Linear increment: ~0.013 per 400ms ≈ reaches 0.95 in ~29 seconds
    _progressTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) {
        setState(() {
          _progress = (_progress + 0.013).clamp(0.0, 0.95);
        });
      }
    });
  }

  void _stopProgressTimer({bool complete = false}) {
    _progressTimer?.cancel();
    _progressTimer = null;
    if (complete && mounted) {
      setState(() => _progress = 1.0);
    }
  }

  Future<void> _generateMealPlan() async {
    final totalMealCount = (_daysCount * _mealsPerDay).toInt();
    final scanned = ref.read(scannedIngredientsProvider);

    AnalyticsService.instance.logButtonTap(
      buttonId: 'generate_meal_plan',
      screenName: 'home',
    );

    final preferenceDto = MealPreferenceDto(
      spicyRating: _spicyRating,
      saltRating: _saltRating,
      dayCount: _daysCount.toInt(),
      priceRating: _priceRating,
      totalMealCount: totalMealCount,
      mealPerDay: _mealsPerDay.toInt(),
      agesOfTheMembers: [24],
      availableIngredients:
          scanned.isEmpty ? null : scanned.map((e) => e.toJson()).toList(),
    );

    setState(() => _isGenerating = true);
    _startProgressTimer();
    // Keep CPU/screen alive so Android doesn't kill the socket mid-request.
    WakelockPlus.enable();

    try {
      await ref.read(mealPlanningProvider.notifier).generateMealPlan(preferenceDto);

      String priceLabel;
      if (_priceRating <= 2) {
        priceLabel = 'budget';
      } else if (_priceRating <= 4) {
        priceLabel = 'standard';
      } else {
        priceLabel = 'premium';
      }
      AnalyticsService.instance.logMealPlanGenerated(
        days: _daysCount.toInt(),
        mealsPerDay: _mealsPerDay.toInt(),
        spiciness: _spicyRating,
        saltiness: _saltRating,
        priceRange: priceLabel,
      );

      _stopProgressTimer(complete: true);
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) context.go('/dashboard/meals?view=suggested');
    } catch (e) {
      _stopProgressTimer();
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _progress = 0.0;
        });
        if (e is DioException) {
          ApiErrorHandler.handleError(e, context);
        } else {
          final errorMessage = e.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      WakelockPlus.disable();
    }
  }

  Widget _buildScannedIngredientsBanner(List<ScannedIngredient> ingredients) {
    return GlassCard(
      blur: 12,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.kitchen_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scanned Ingredients',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () =>
                    ref.read(scannedIngredientsProvider.notifier).clear(),
                child: Icon(Icons.close, size: 18, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'These will be prioritised in your next meal plan.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: List.generate(ingredients.length, (i) {
              final ing = ingredients[i];
              return Chip(
                label: Text(
                  ing.quantity.isNotEmpty
                      ? '${ing.name} · ${ing.quantity}'
                      : ing.name,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textPrimary)),
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                deleteIcon: Icon(Icons.close,
                    size: 14, color: AppColors.textPrimary),
                onDeleted: () {
                  final updated = List<ScannedIngredient>.from(ingredients)
                    ..removeAt(i);
                  ref
                      .read(scannedIngredientsProvider.notifier)
                      .setIngredients(updated);
                },
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final scannedIngredients = ref.watch(scannedIngredientsProvider);
    return PopScope(
      canPop: !_isGenerating,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 36),

              // Scanned ingredients banner (visible only after a scan)
              if (scannedIngredients.isNotEmpty)
                _buildScannedIngredientsBanner(scannedIngredients),

              // Header Section
              GlassCard(
                blur: 10,
                child: Column(
                  children: [
                    Text(
                      'Plan Your Meals',
                      style: AppTextStyles.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Customize your preferences to get AI-generated meal suggestions.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Form Section
              GlassCard(
                blur: 20,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomSlider(
                      label: 'Spiciness',
                      value: _spicyRating,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged: _isGenerating ? null : (v) => setState(() => _spicyRating = v),
                      labelBuilder: (v) => '${v.toInt()}/10',
                    ),
                    const SizedBox(height: 20),

                    CustomSlider(
                      label: 'Saltiness',
                      value: _saltRating,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged: _isGenerating ? null : (v) => setState(() => _saltRating = v),
                      labelBuilder: (v) => '${v.toInt()}/10',
                    ),
                    const SizedBox(height: 20),

                    CustomSlider(
                      label: 'Price Range',
                      value: _priceRating,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      onChanged: _isGenerating ? null : (v) => setState(() => _priceRating = v),
                      labelBuilder: (v) {
                        if (v <= 2) return 'Budget';
                        if (v <= 4) return 'Standard';
                        return 'Premium';
                      },
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: CustomSlider(
                            label: 'Days',
                            value: _daysCount,
                            min: 1,
                            max: 7,
                            divisions: 6,
                            onChanged: _isGenerating ? null : (v) => setState(() => _daysCount = v),
                            labelBuilder: (v) => '${v.toInt()} Days',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomSlider(
                            label: 'Meals/Day',
                            value: _mealsPerDay,
                            min: 1,
                            max: 5,
                            divisions: 4,
                            onChanged: _isGenerating ? null : (v) => setState(() => _mealsPerDay = v),
                            labelBuilder: (v) => '${v.toInt()} Meals',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _GlowFridgeButton(
                      onPressed: _isGenerating
                          ? null
                          : () => context.push('/dashboard/fridge_scan'),
                    ),

                    const SizedBox(height: 16),

                    GlassButton(
                      text: 'Generate Meal Plan 🪄',
                      onPressed: _isGenerating ? null : _generateMealPlan,
                      gradient: AppColors.bgGradient1,
                      progress: _isGenerating ? _progress : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated glow fridge button ───────────────────────────────────────────────

class _GlowFridgeButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const _GlowFridgeButton({required this.onPressed});

  @override
  State<_GlowFridgeButton> createState() => _GlowFridgeButtonState();
}

class _GlowFridgeButtonState extends State<_GlowFridgeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final blur = disabled ? 0.0 : 14.0 + 22.0 * _glow.value;
        final alpha = disabled ? 0.0 : 0.3 + 0.4 * _glow.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: alpha),
                blurRadius: blur,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: AppColors.primaryLight.withValues(alpha: alpha * 0.5),
                blurRadius: blur * 1.6,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(20),
          splashColor: AppColors.primary.withValues(alpha: 0.12),
          highlightColor: AppColors.primary.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: disabled
                    ? AppColors.glassBorder
                    : AppColors.primary.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.kitchen_rounded,
                      size: 22, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Show your Fridge',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Let AI plan meals from what you have',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
