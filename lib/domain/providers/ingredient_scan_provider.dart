import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A scanned ingredient with its detected quantity.
class ScannedIngredient {
  final String name;
  final String quantity;

  const ScannedIngredient({required this.name, required this.quantity});

  Map<String, String> toJson() => {'name': name, 'quantity': quantity};
}

/// Holds scanned ingredients (name + quantity) chosen to include in meal suggestions.
final scannedIngredientsProvider =
    StateNotifierProvider<ScannedIngredientsNotifier, List<ScannedIngredient>>(
  (ref) => ScannedIngredientsNotifier(),
);

class ScannedIngredientsNotifier extends StateNotifier<List<ScannedIngredient>> {
  ScannedIngredientsNotifier() : super([]);

  void setIngredients(List<ScannedIngredient> ingredients) {
    state = ingredients;
  }

  void clear() {
    state = [];
  }
}
