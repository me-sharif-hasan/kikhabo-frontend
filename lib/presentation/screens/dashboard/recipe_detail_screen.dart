import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/recipe.dart';
import '../../../domain/providers/recipe_provider.dart';
import '../../../domain/providers/user_provider.dart';
import '../../widgets/youtube_video_carousel.dart';

class RecipeDetailScreen extends ConsumerWidget {
  final RecipeItem recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  /// Builds the YouTube search term: "Recipe Name (UserCountry)" when the
  /// logged-in user has a country set, otherwise falls back to "Recipe Name recipe".
  List<String> _searchTerms(String? userCountry) {
    final name = recipe.name;
    if (userCountry != null && userCountry.trim().isNotEmpty) {
      return ['$name (${userCountry.trim()})'];
    }
    return ['$name recipe'];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final detailAsync = ref.watch(recipeDetailProvider(recipe.id));
    final userCountry = ref.watch(userProvider).user?.country;
    final searchTerms = _searchTerms(userCountry);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          AdService.instance.show(onDone: () => context.pop());
        }
      },
      child: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image with bookmark button overlay
            Stack(
              children: [
                _HeroImage(imageUrl: recipe.image, name: recipe.name),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _BookmarkButton(recipeId: recipe.id),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    recipe.name,
                    style: AppTextStyles.headlineMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),

                  // Meta chips
                  const SizedBox(height: 14),
                  _MetaRow(recipe: recipe),

                  // About — available immediately from the list response
                  if (recipe.description != null &&
                      recipe.description!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'About'),
                    const SizedBox(height: 10),
                    _ContentCard(
                      child: Text(
                        recipe.description!,
                        style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
                      ),
                    ),
                  ],

                  // YouTube carousel — shown immediately, no detail needed
                  const SizedBox(height: 24),
                  YouTubeVideoCarousel(searchTerms: searchTerms),

                  // Ingredients & cooking guide — skeleton while loading
                  const SizedBox(height: 24),
                  detailAsync.when(
                    loading: () => _RecipeDetailSkeleton(),
                    error: (e, _) => _ErrorSection(message: e.toString()),
                    data: (detail) => _DetailContent(detail: detail),
                  ),
                ],
              ),
            ),
          ],
        ),
      ), // SingleChildScrollView
      ), // SafeArea
    ); // PopScope
  }
}

// ── Hero image ────────────────────────────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  final String? imageUrl;
  final String name;

  const _HeroImage({required this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _heroFallback(),
              placeholder: (_, __) => _heroFallback(loading: true),
            )
          else
            _heroFallback(),

          // Bottom fade-out into background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.background.withValues(alpha: 0.9),
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroFallback({bool loading = false}) => Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/sidebar_bg.gif', fit: BoxFit.cover),
          Center(
            child: loading
                ? CircularProgressIndicator(color: Colors.white70)
                : Image.asset('assets/logo.png', width: 72, height: 72),
          ),
        ],
      );
}

// ── Meta chips row ────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final RecipeItem recipe;

  const _MetaRow({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final prep = _formatDuration(recipe.prepTime);
    final cook = _formatDuration(recipe.cookTime);
    final chips = <_MetaChip>[];

    if (prep.isNotEmpty) chips.add(_MetaChip(icon: Icons.timer_outlined, label: 'Prep', value: prep));
    if (cook.isNotEmpty) chips.add(_MetaChip(icon: Icons.local_fire_department_outlined, label: 'Cook', value: cook));
    if (recipe.recipeYield != null)
      chips.add(_MetaChip(icon: Icons.people_alt_outlined, label: 'Serves', value: _cleanYield(recipe.recipeYield!)));
    if (recipe.source != null)
      chips.add(_MetaChip(icon: Icons.link_rounded, label: 'Source', value: _capitalize(recipe.source!)));

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 10, runSpacing: 10, children: chips);
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryOnSurface),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Loading / error states ────────────────────────────────────────────────────

class _RecipeDetailSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBlock(height: 18, width: 110),
        const SizedBox(height: 10),
        _SkeletonCard(lineCount: 5),
        const SizedBox(height: 24),
        _SkeletonBlock(height: 18, width: 140),
        const SizedBox(height: 10),
        _SkeletonCard(lineCount: 8),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double height;
  final double width;
  const _SkeletonBlock({required this.height, required this.width});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppColors.glassBorder.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
      );
}

class _SkeletonCard extends StatelessWidget {
  final int lineCount;
  const _SkeletonCard({required this.lineCount});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(lineCount, (i) {
            final isShort = i == lineCount - 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                height: 12,
                width: isShort
                    ? MediaQuery.of(context).size.width * 0.45
                    : double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.glassBorder.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
      );
}

class _LoadingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
        children: [
          const SizedBox(height: 32),
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Loading recipe details...',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      );
}

class _ErrorSection extends StatelessWidget {
  final String message;

  const _ErrorSection({required this.message});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error),
          const SizedBox(height: 8),
          Text('Could not load details', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 4),
          Text(message, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
        ],
      );
}

// ── Full detail content ───────────────────────────────────────────────────────

class _DetailContent extends StatelessWidget {
  final RecipeDetail detail;

  const _DetailContent({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ingredients
        if (detail.ingredients != null && detail.ingredients!.isNotEmpty) ...[
          _SectionHeader(title: 'Ingredients'),
          const SizedBox(height: 10),
          _ContentCard(child: _IngredientsList(raw: detail.ingredients!)),
          const SizedBox(height: 24),
        ],

        // Cooking guide
        if (detail.cookingGuide != null && detail.cookingGuide!.isNotEmpty) ...[
          _SectionHeader(title: 'How to Cook'),
          const SizedBox(height: 10),
          _ContentCard(child: _CookingGuide(raw: detail.cookingGuide!)),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.primaryOnSurface,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(title, style: AppTextStyles.headlineSmall),
        ],
      );
}

class _ContentCard extends StatelessWidget {
  final Widget child;

  const _ContentCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: child,
      );
}

// ── Ingredients list ──────────────────────────────────────────────────────────

class _IngredientsList extends StatelessWidget {
  final String raw;

  const _IngredientsList({required this.raw});

  @override
  Widget build(BuildContext context) {
    final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 10),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.primaryOnSurface,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  line.trim(),
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Cooking guide with rich text parsing ──────────────────────────────────────

class _CookingGuide extends StatelessWidget {
  final String raw;

  const _CookingGuide({required this.raw});

  @override
  Widget build(BuildContext context) {
    final lines = raw.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed == '---') {
        widgets.add(Divider(color: AppColors.glassBorder, height: 28));
      } else if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
      } else if (RegExp(r'^\*\s').hasMatch(trimmed)) {
        // Bullet point
        final content = trimmed.replaceFirst(RegExp(r'^\*\s+'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Text(
                    '•',
                    style: TextStyle(
                      color: AppColors.primaryOnSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(child: _inlineText(content)),
              ],
            ),
          ),
        );
      } else if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        // Numbered step
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _inlineText(trimmed),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _inlineText(line),
          ),
        );
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _inlineText(String text) {
    final spans = <TextSpan>[];
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in boldPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: AppColors.textSecondary, height: 1.6),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          height: 1.6,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: AppColors.textSecondary, height: 1.6),
      ));
    }

    return RichText(
      text: TextSpan(
        style: AppTextStyles.bodyMedium,
        children: spans.isEmpty
            ? [TextSpan(
                text: text,
                style: TextStyle(color: AppColors.textSecondary, height: 1.6),
              )]
            : spans,
      ),
    );
  }
}

// ── Bookmark button ───────────────────────────────────────────────────────────

class _BookmarkButton extends ConsumerWidget {
  final String recipeId;

  const _BookmarkButton({required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBookmarked = ref.watch(
      bookmarkProvider.select((s) => s.isBookmarked(recipeId)),
    );

    return GestureDetector(
      onTap: () => ref.read(bookmarkProvider.notifier).toggle(recipeId),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isBookmarked ? AppColors.accent : Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatDuration(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final h = RegExp(r'(\d+)H').firstMatch(iso)?.group(1);
  final m = RegExp(r'(\d+)M').firstMatch(iso)?.group(1);
  return [if (h != null) '${h}h', if (m != null) '${m}m'].join(' ');
}

String _cleanYield(String raw) {
  final firstLine = raw.split('\n').first;
  return firstLine.replaceAll(RegExp(r'(Makes|Serves|makes|serves)\s*'), '').trim();
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
