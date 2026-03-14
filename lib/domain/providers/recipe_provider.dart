import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/recipe_datasource.dart';
import '../../data/models/recipe.dart';
import '../../data/repositories/recipe_repository.dart';
import 'auth_provider.dart';

final recipeDataSourceProvider = Provider<RecipeDataSource>((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  return RecipeDataSource(dio);
});

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(recipeDataSourceProvider));
});

/// Random recipes shown on the dashboard — cached for the session.
final randomRecipesProvider = FutureProvider<List<RecipeItem>>((ref) {
  return ref.watch(recipeRepositoryProvider).getRandomRecipes(limit: 5);
});

/// Full recipe detail for a given ID — auto-disposed when off-screen.
final recipeDetailProvider =
    FutureProvider.autoDispose.family<RecipeDetail, String>((ref, id) {
  return ref.watch(recipeRepositoryProvider).getRecipeDetail(id);
});

// ── Recipe list state ─────────────────────────────────────────────────────────

class RecipeListState {
  final List<RecipeItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String query;
  final String? error;

  const RecipeListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.query = '',
    this.error,
  });

  RecipeListState copyWith({
    List<RecipeItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? query,
    String? error,
    bool clearError = false,
  }) {
    return RecipeListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      query: query ?? this.query,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

typedef _PageFetcher = Future<RecipePage> Function({
  int page,
  int size,
  String? search,
});

class RecipeListNotifier extends StateNotifier<RecipeListState> {
  final _PageFetcher _fetcher;

  RecipeListNotifier(this._fetcher) : super(const RecipeListState()) {
    _load(page: 0, replace: true);
  }

  Future<void> _load({
    required int page,
    required bool replace,
    String? query,
  }) async {
    if (replace) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else {
      if (state.isLoadingMore) return;
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final result = await _fetcher(
        page: page,
        size: 20,
        search: query ?? state.query,
      );
      final merged = replace
          ? result.recipes
          : [...state.items, ...result.recipes];
      state = state.copyWith(
        items: merged,
        isLoading: false,
        isLoadingMore: false,
        currentPage: page,
        hasMore: page < result.totalPages - 1,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(query: query);
    await _load(page: 0, replace: true, query: query);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    await _load(page: state.currentPage + 1, replace: false);
  }

  Future<void> refresh() => _load(page: 0, replace: true);
}

final recipeListProvider =
    StateNotifierProvider<RecipeListNotifier, RecipeListState>((ref) {
  final repo = ref.watch(recipeRepositoryProvider);
  return RecipeListNotifier(repo.getRecipes);
});

final bookmarksListProvider =
    StateNotifierProvider<RecipeListNotifier, RecipeListState>((ref) {
  final repo = ref.watch(recipeRepositoryProvider);
  return RecipeListNotifier(repo.getBookmarks);
});

// ── Bookmark state ────────────────────────────────────────────────────────────

class BookmarkState {
  final Set<String> ids;
  final bool isLoading;

  const BookmarkState({this.ids = const {}, this.isLoading = false});

  bool isBookmarked(String id) => ids.contains(id);

  BookmarkState copyWith({Set<String>? ids, bool? isLoading}) =>
      BookmarkState(
        ids: ids ?? this.ids,
        isLoading: isLoading ?? this.isLoading,
      );
}

class BookmarkNotifier extends StateNotifier<BookmarkState> {
  final RecipeRepository _repository;
  final Ref _ref;

  BookmarkNotifier(this._repository, this._ref)
      : super(const BookmarkState()) {
    _loadAllIds();
  }

  Future<void> _loadAllIds() async {
    state = state.copyWith(isLoading: true);
    try {
      final page = await _repository.getBookmarks(page: 0, size: 200);
      state = BookmarkState(ids: page.recipes.map((r) => r.id).toSet());
    } catch (_) {
      state = const BookmarkState();
    }
  }

  Future<void> toggle(String id) async {
    final wasBookmarked = state.isBookmarked(id);
    // Optimistic update
    final newIds = Set<String>.from(state.ids);
    if (wasBookmarked) {
      newIds.remove(id);
    } else {
      newIds.add(id);
    }
    state = state.copyWith(ids: newIds);

    try {
      if (wasBookmarked) {
        await _repository.removeBookmark(id);
      } else {
        await _repository.bookmarkRecipe(id);
      }
      // Refresh the bookmarks list so it's up to date
      _ref.invalidate(bookmarksListProvider);
    } catch (_) {
      // Revert on failure
      final revertIds = Set<String>.from(state.ids);
      if (wasBookmarked) {
        revertIds.add(id);
      } else {
        revertIds.remove(id);
      }
      state = state.copyWith(ids: revertIds);
    }
  }

  Future<void> refresh() => _loadAllIds();
}

final bookmarkProvider =
    StateNotifierProvider<BookmarkNotifier, BookmarkState>((ref) {
  return BookmarkNotifier(ref.watch(recipeRepositoryProvider), ref);
});
