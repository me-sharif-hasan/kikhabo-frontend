import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/api_error_handler.dart';
import '../../../data/datasources/recipe_datasource.dart';
import '../../../data/models/meal.dart';
import '../../../data/models/recipe.dart';
import '../../../domain/providers/meal_provider.dart';
import '../../../domain/providers/ingredient_scan_provider.dart';
import '../../../domain/providers/recipe_provider.dart';
import '../../../domain/providers/user_provider.dart';
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

  void _openSearch() {
    final dataSource = ref.read(recipeDataSourceProvider);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close search',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
        child: child,
      ),
      pageBuilder: (ctx, a1, a2) => _SearchOverlay(
        dataSource: dataSource,
        parentContext: context,
      ),
    );
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
                    fontSize: 12,
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: AppColors.primaryDark,
                side: BorderSide.none,
                deleteIcon: Icon(Icons.close, size: 14, color: AppColors.onPrimary),
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
    final randomAsync = ref.watch(randomRecipesProvider);
    final user = ref.watch(userProvider).user;
    return PopScope(
      canPop: !_isGenerating,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // ── Hero banner (search + greeting + actions) ─────────────────
              _HeroBanner(
                userName: user?.firstName,
                onSearchTap: _openSearch,
                onBrowseTap: () => context.push('/dashboard/recipes'),
              ),
              const SizedBox(height: 16),

              // Scanned ingredients banner (visible only after a scan)
              if (scannedIngredients.isNotEmpty)
                _buildScannedIngredientsBanner(scannedIngredients),

              const SizedBox(height: 4),

              // Form Section
              GlassCard(
                blur: 20,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Spiciness + Saltiness side by side
                    Row(
                      children: [
                        Expanded(
                          child: CustomSlider(
                            label: 'Spiciness',
                            value: _spicyRating,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            onChanged: _isGenerating ? null : (v) => setState(() => _spicyRating = v),
                            labelBuilder: (v) => '${v.toInt()}/10',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomSlider(
                            label: 'Saltiness',
                            value: _saltRating,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            onChanged: _isGenerating ? null : (v) => setState(() => _saltRating = v),
                            labelBuilder: (v) => '${v.toInt()}/10',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

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
                    const SizedBox(height: 12),

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
                        const SizedBox(width: 12),
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
                    const SizedBox(height: 14),

                    _GlowFridgeButton(
                      onPressed: _isGenerating
                          ? null
                          : () => context.push('/dashboard/fridge_scan'),
                    ),

                    const SizedBox(height: 10),

                    _GenerateButton(
                      isGenerating: _isGenerating,
                      progress: _progress,
                      onPressed: _generateMealPlan,
                    ),
                  ],
                ),
              ),

              // ── Discover Recipes section ─────────────────────────────────
              const SizedBox(height: 28),
              _RandomRecipesSection(randomAsync: randomAsync),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Generate button — isolated so the progress timer only rebuilds this widget ─

class _GenerateButton extends StatefulWidget {
  final bool isGenerating;
  final double progress;
  final VoidCallback onPressed;

  const _GenerateButton({
    required this.isGenerating,
    required this.progress,
    required this.onPressed,
  });

  @override
  State<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends State<_GenerateButton> {
  @override
  Widget build(BuildContext context) {
    return GlassButton(
      text: 'Generate Meal Plan 🪄',
      onPressed: widget.isGenerating ? null : widget.onPressed,
      gradient: AppColors.bgGradient1,
      progress: widget.isGenerating ? widget.progress : null,
    );
  }
}

// ── Fridge button (static — no continuous animation) ─────────────────────────

class _GlowFridgeButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _GlowFridgeButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: AppColors.primary.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.kitchen_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
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
    );
  }
}

// ── Hero banner (greeting + search + action pills) ────────────────────────────

class _HeroBanner extends StatelessWidget {
  final String? userName;
  final VoidCallback onSearchTap;
  final VoidCallback onBrowseTap;

  const _HeroBanner({
    required this.userName,
    required this.onSearchTap,
    required this.onBrowseTap,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = userName != null && userName!.isNotEmpty ? userName! : 'there';
    return GlassCard(
      blur: 14,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            '${_greeting()}, $name! 👋',
            style: AppTextStyles.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Plan your meals or explore dishes from around the world.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),

          // Joined search + browse bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                // Search side
                Expanded(
                  child: GestureDetector(
                    onTap: onSearchTap,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Search recipes...',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Vertical divider
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.glassBorder,
                ),

                // Browse button
                GestureDetector(
                  onTap: onBrowseTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    child: Row(
                      children: [
                        Icon(Icons.menu_book_rounded,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Browse',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Random recipes section ────────────────────────────────────────────────────

class _RandomRecipesSection extends StatelessWidget {
  final AsyncValue<List<RecipeItem>> randomAsync;

  const _RandomRecipesSection({required this.randomAsync});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discover Recipes', style: AppTextStyles.titleMedium),
                  Text(
                    'Hand-picked dishes to inspire you',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/dashboard/recipes'),
              child: Row(
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Cards
        SizedBox(
          height: 210,
          child: randomAsync.when(
            loading: () => ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (_, __) => const _RandomRecipeCardSkeleton(),
            ),
            error: (_, __) => Center(
              child: Text('Could not load recipes', style: AppTextStyles.bodySmall),
            ),
            data: (recipes) => ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: recipes.length,
              itemBuilder: (_, i) => _RandomRecipeCard(recipe: recipes[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _RandomRecipeCard extends StatelessWidget {
  final RecipeItem recipe;

  const _RandomRecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/dashboard/recipe_detail', extra: recipe),
      child: Container(
        width: 158,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: recipe.image != null && recipe.image!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: recipe.image!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _cardPlaceholder(),
                        placeholder: (_, __) => _cardPlaceholder(loading: true),
                      )
                    : _cardPlaceholder(),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    if (recipe.source != null)
                      Text(
                        recipe.source!,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardPlaceholder({bool loading = false}) => Container(
        color: AppColors.surface,
        child: Center(
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2),
                )
              : Image.asset('assets/sidebar_bg.gif'),
        ),
      );
}

class _RandomRecipeCardSkeleton extends StatelessWidget {
  const _RandomRecipeCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 158,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Container(
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.glassBorder,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 10, width: 120, color: AppColors.glassBorder,
                    margin: const EdgeInsets.only(bottom: 6)),
                Container(height: 10, width: 80, color: AppColors.glassBorder),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search overlay popup ──────────────────────────────────────────────────────

class _SearchOverlay extends StatefulWidget {
  final RecipeDataSource dataSource;
  final BuildContext parentContext;

  const _SearchOverlay({required this.dataSource, required this.parentContext});

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<RecipeItem> _results = [];
  bool _loading = false;
  String _lastQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String query) async {
    _lastQuery = query;
    try {
      final page = await widget.dataSource.getRecipes(search: query, size: 8);
      if (mounted && _lastQuery == query) {
        setState(() {
          _results = page.recipes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onRecipeTap(RecipeItem recipe) {
    Navigator.of(context).pop();
    widget.parentContext.push('/dashboard/recipe_detail', extra: recipe);
  }

  void _seeAll() {
    final q = _controller.text.trim();
    Navigator.of(context).pop();
    widget.parentContext.push('/dashboard/recipes?q=${Uri.encodeComponent(q)}');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // Search bar row
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.glass,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: _onChanged,
                        onSubmitted: (_) {
                          if (_controller.text.trim().isNotEmpty) _seeAll();
                        },
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search recipes...',
                          hintStyle: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: AppColors.primary, size: 20),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      color: AppColors.textSecondary, size: 18),
                                  onPressed: () {
                                    _controller.clear();
                                    _onChanged('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: AppColors.glassBorder, height: 20),

            // Content area
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_controller.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded,
                size: 56, color: AppColors.primary.withValues(alpha: 0.25)),
            const SizedBox(height: 14),
            Text('Type to search recipes',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                )),
          ],
        ),
      );
    }

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text('No results found', style: AppTextStyles.bodyMedium),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _results.length,
            itemBuilder: (_, i) {
              final r = _results[i];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: r.image != null && r.image!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: r.image!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _tileImgFallback(),
                            placeholder: (_, __) => _tileImgFallback(),
                          )
                        : _tileImgFallback(),
                  ),
                ),
                title: Text(
                  r.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textPrimary, fontSize: 13),
                ),
                subtitle: r.source != null
                    ? Text(r.source!,
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500))
                    : null,
                trailing: Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: AppColors.textSecondary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () => _onRecipeTap(r),
              );
            },
          ),
        ),

        // See all results
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: GestureDetector(
            onTap: _seeAll,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'See all results for "${_controller.text}"',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded,
                      size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tileImgFallback() => Container(
        color: AppColors.glass,
        child: Icon(Icons.restaurant_rounded,
            size: 20, color: AppColors.primary.withValues(alpha: 0.35)),
      );
}
