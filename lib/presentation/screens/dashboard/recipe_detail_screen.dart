import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/recipe.dart';
import '../../../domain/providers/recipe_provider.dart';

class RecipeDetailScreen extends ConsumerWidget {
  final RecipeItem recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final detailAsync = ref.watch(recipeDetailProvider(recipe.id));

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image — sits behind the transparent AppBar
            _HeroImage(imageUrl: recipe.image, name: recipe.name),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
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

                  // Detail body
                  const SizedBox(height: 24),
                  detailAsync.when(
                    loading: () => _LoadingSection(),
                    error: (e, _) => _ErrorSection(message: e.toString()),
                    data: (detail) => _DetailContent(detail: detail),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _heroFallback({bool loading = false}) => Container(
        color: AppColors.surface,
        child: Center(
          child: loading
              ? CircularProgressIndicator(color: AppColors.primary)
              : Icon(
                  Icons.restaurant_menu_rounded,
                  size: 72,
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
        ),
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
          Icon(icon, size: 14, color: AppColors.primary),
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
        // About / description
        if (detail.description != null && detail.description!.isNotEmpty) ...[
          _SectionHeader(title: 'About'),
          const SizedBox(height: 10),
          _ContentCard(
            child: Text(
              detail.description!,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
            ),
          ),
          const SizedBox(height: 24),
        ],

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
              color: AppColors.primary,
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
                    color: AppColors.primary,
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
                      color: AppColors.primary,
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

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatDuration(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final h = RegExp(r'(\d+)H').firstMatch(iso)?.group(1);
  final m = RegExp(r'(\d+)M').firstMatch(iso)?.group(1);
  return [if (h != null) '${h}h', if (m != null) '${m}m'].join(' ');
}

String _cleanYield(String raw) =>
    raw.replaceAll(RegExp(r'(Makes|Serves|makes|serves)\s*'), '').trim();

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
