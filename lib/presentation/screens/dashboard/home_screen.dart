import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/api_error_handler.dart';
import '../../../data/models/meal.dart';
import '../../../domain/providers/meal_provider.dart';
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
    );

    setState(() => _isGenerating = true);
    _startProgressTimer();

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
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    return PopScope(
      canPop: !_isGenerating,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 60),

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
                    const SizedBox(height: 40),

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
