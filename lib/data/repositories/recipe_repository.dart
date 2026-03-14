import '../datasources/recipe_datasource.dart';
import '../models/recipe.dart';

class RecipeRepository {
  final RecipeDataSource _dataSource;

  RecipeRepository(this._dataSource);

  Future<RecipePage> getRecipes({int page = 0, int size = 20, String? search}) =>
      _dataSource.getRecipes(page: page, size: size, search: search);

  Future<RecipeDetail> getRecipeDetail(String id) =>
      _dataSource.getRecipeDetail(id);

  Future<List<RecipeItem>> getRandomRecipes({int limit = 5}) =>
      _dataSource.getRandomRecipes(limit: limit);

  Future<void> bookmarkRecipe(String id) => _dataSource.bookmarkRecipe(id);

  Future<void> removeBookmark(String id) => _dataSource.removeBookmark(id);

  Future<RecipePage> getBookmarks({int page = 0, int size = 20, String? search}) =>
      _dataSource.getBookmarks(page: page, size: size, search: search);
}
