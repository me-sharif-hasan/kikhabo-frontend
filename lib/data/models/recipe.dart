class RecipeItem {
  final String id;
  final String name;
  final String? source;
  final String? url;
  final String? image;
  final String? cookTime;
  final String? prepTime;
  final String? recipeYield;
  final String? datePublished;
  final String? description;
  final String? country;

  const RecipeItem({
    required this.id,
    required this.name,
    this.source,
    this.url,
    this.image,
    this.cookTime,
    this.prepTime,
    this.recipeYield,
    this.datePublished,
    this.description,
    this.country,
  });

  factory RecipeItem.fromJson(Map<String, dynamic> json) => RecipeItem(
        id: json['id'] as String? ?? '',
        name: _decodeHtml(json['name'] as String? ?? ''),
        source: json['source'] as String?,
        url: json['url'] as String?,
        image: json['image'] as String?,
        cookTime: json['cookTime'] as String?,
        prepTime: json['prepTime'] as String?,
        recipeYield: json['recipeYield'] as String?,
        datePublished: json['datePublished'] as String?,
        description: json['description'] as String?,
        country: json['country'] as String?,
      );

  static String _decodeHtml(String text) => text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}

class RecipeDetail extends RecipeItem {
  final String? ingredients;
  final String? cookingGuide;

  const RecipeDetail({
    required super.id,
    required super.name,
    super.source,
    super.url,
    super.image,
    super.cookTime,
    super.prepTime,
    super.recipeYield,
    super.datePublished,
    super.description,
    super.country,
    this.ingredients,
    this.cookingGuide,
  });

  factory RecipeDetail.fromJson(Map<String, dynamic> json) {
    final base = RecipeItem.fromJson(json);
    return RecipeDetail(
      id: base.id,
      name: base.name,
      source: base.source,
      url: base.url,
      image: base.image,
      cookTime: base.cookTime,
      prepTime: base.prepTime,
      recipeYield: base.recipeYield,
      datePublished: base.datePublished,
      description: base.description,
      country: base.country,
      ingredients: json['ingredients'] as String?,
      cookingGuide: json['cookingGuide'] as String?,
    );
  }
}

class RecipePage {
  final List<RecipeItem> recipes;
  final int totalElements;
  final int totalPages;
  final int currentPage;
  final int pageSize;

  const RecipePage({
    required this.recipes,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
  });

  factory RecipePage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final list = (data['recipes'] as List<dynamic>)
        .map((e) => RecipeItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return RecipePage(
      recipes: list,
      totalElements: data['totalElements'] as int? ?? 0,
      totalPages: data['totalPages'] as int? ?? 0,
      currentPage: data['currentPage'] as int? ?? 0,
      pageSize: data['pageSize'] as int? ?? 20,
    );
  }
}
