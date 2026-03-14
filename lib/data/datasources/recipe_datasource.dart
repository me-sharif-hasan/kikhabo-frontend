import 'package:dio/dio.dart';
import '../models/recipe.dart';
import '../../core/constants/api_constants.dart';

class RecipeDataSource {
  final Dio _dio;

  RecipeDataSource(this._dio);

  Future<RecipePage> getRecipes({
    int page = 0,
    int size = 20,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page, 'size': size};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _dio.get(ApiConstants.recipes, queryParameters: params);
    return RecipePage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RecipeDetail> getRecipeDetail(String id) async {
    final response = await _dio.get('${ApiConstants.recipes}/$id');
    final data = (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return RecipeDetail.fromJson(data);
  }

  Future<List<RecipeItem>> getRandomRecipes({int limit = 5}) async {
    final response = await _dio.get(
      ApiConstants.recipesRandom,
      queryParameters: {'limit': limit},
    );
    final list = (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return list.map((e) => RecipeItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> bookmarkRecipe(String id) async {
    await _dio.post('${ApiConstants.recipes}/$id/bookmark');
  }

  Future<void> removeBookmark(String id) async {
    await _dio.delete('${ApiConstants.recipes}/$id/bookmark');
  }

  Future<RecipePage> getBookmarks({
    int page = 0,
    int size = 20,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page, 'size': size};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _dio.get(ApiConstants.recipesBookmarks, queryParameters: params);
    return RecipePage.fromJson(response.data as Map<String, dynamic>);
  }
}
