import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/recipe.dart';
import '../../../domain/providers/recipe_provider.dart';

class RecipeListScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final bool bookmarksMode;

  const RecipeListScreen({super.key, this.initialQuery, this.bookmarksMode = false});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  String? _pendingSearch;

  bool get _isBookmarks => widget.bookmarksMode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _scrollController = ScrollController()..addListener(_onScroll);

    if (!_isBookmarks &&
        widget.initialQuery != null &&
        widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(recipeListProvider.notifier).search(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (_isBookmarks) {
        ref.read(bookmarksListProvider.notifier).loadMore();
      } else {
        ref.read(recipeListProvider.notifier).loadMore();
      }
    }
  }

  void _onSearchChanged(String value) {
    _pendingSearch = value;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_pendingSearch == value && mounted) {
        if (_isBookmarks) {
          ref.read(bookmarksListProvider.notifier).search(value);
        } else {
          ref.read(recipeListProvider.notifier).search(value);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final state = _isBookmarks
        ? ref.watch(bookmarksListProvider)
        : ref.watch(recipeListProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 44),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isBookmarks ? 'Bookmarks' : 'Recipes',
                  style: AppTextStyles.headlineMedium,
                ),
                Text(
                  _isBookmarks
                      ? 'Your saved recipes'
                      : 'Discover dishes from around the world',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 14),
                _SearchBar(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  hint: _isBookmarks ? 'Search bookmarks...' : 'Search recipes...',
                  onClear: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () => _isBookmarks
                  ? ref.read(bookmarksListProvider.notifier).refresh()
                  : ref.read(recipeListProvider.notifier).refresh(),
              child: _buildContent(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(RecipeListState state) {
    if (state.isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.textSecondary),
              const SizedBox(height: 14),
              Text(state.error!, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => _isBookmarks
                    ? ref.read(bookmarksListProvider.notifier).refresh()
                    : ref.read(recipeListProvider.notifier).refresh(),
                child: Text('Try again', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isBookmarks ? Icons.bookmark_border_rounded : Icons.search_off_rounded,
                size: 52,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                _isBookmarks ? 'No bookmarks yet' : 'No recipes found',
                style: AppTextStyles.bodyMedium,
              ),
              if (_isBookmarks) ...[
                const SizedBox(height: 6),
                Text(
                  'Tap the bookmark icon on any recipe to save it here',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: state.isLoadingMore
                  ? CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)
                  : const SizedBox.shrink(),
            ),
          );
        }
        return _RecipeCard(
          recipe: state.items[index],
          onTap: () => context.push('/dashboard/recipe_detail', extra: state.items[index]),
        );
      },
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hint;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hint = 'Search recipes...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ── Recipe card ───────────────────────────────────────────────────────────────

class _RecipeCard extends ConsumerWidget {
  final RecipeItem recipe;
  final VoidCallback onTap;

  const _RecipeCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prepTime = _formatDuration(recipe.prepTime);
    final cookTime = _formatDuration(recipe.cookTime);
    final isBookmarked = ref.watch(
      bookmarkProvider.select((s) => s.isBookmarked(recipe.id)),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              child: SizedBox(
                width: 108,
                height: 108,
                child: _RecipeImage(imageUrl: recipe.image),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    if (recipe.description != null &&
                        recipe.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        recipe.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (prepTime.isNotEmpty)
                          _TimeBadge(
                            icon: Icons.timer_outlined,
                            label: 'Prep $prepTime',
                          ),
                        if (cookTime.isNotEmpty)
                          _TimeBadge(
                            icon: Icons.local_fire_department_outlined,
                            label: 'Cook $cookTime',
                          ),
                        if (prepTime.isEmpty &&
                            cookTime.isEmpty &&
                            recipe.recipeYield != null)
                          _TimeBadge(
                            icon: Icons.people_outline,
                            label: _cleanYield(recipe.recipeYield!),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bookmark + arrow
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () =>
                        ref.read(bookmarkProvider.notifier).toggle(recipe.id),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 20,
                        color: isBookmarked
                            ? AppColors.onPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: AppColors.textSecondary,
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

class _TimeBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TimeBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 130),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: AppColors.onPrimary),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared image widget with placeholder ──────────────────────────────────────

class _RecipeImage extends StatelessWidget {
  final String? imageUrl;
  final double? size;

  const _RecipeImage({this.imageUrl, this.size});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return _placeholder();
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorWidget: (_, __, ___) => _placeholder(),
      placeholder: (_, __) => _placeholder(loading: true),
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      color: AppColors.glass,
      child: Center(
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
              )
            : Image.asset('assets/logo_bg.png'),
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
