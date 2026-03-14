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

class RecipeListNotifier extends StateNotifier<RecipeListState> {
  final RecipeRepository _repository;

  RecipeListNotifier(this._repository) : super(const RecipeListState()) {
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
      final result = await _repository.getRecipes(
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
  return RecipeListNotifier(ref.watch(recipeRepositoryProvider));
});
