import 'food_item.dart';

class FavoriteFood {
  final String id;
  final FoodItem food;
  final double favoriteQuantity;

  FavoriteFood({
    required this.id,
    required this.food,
    required this.favoriteQuantity,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'food': food.toJson(),
        'favoriteQuantity': favoriteQuantity,
      };

  factory FavoriteFood.fromJson(Map<String, dynamic> json, String docId) => FavoriteFood(
        id: docId,
        food: FoodItem.fromJson(json['food'] ?? {}, ''),
        favoriteQuantity: (json['favoriteQuantity'] as num?)?.toDouble() ?? 100.0,
      );
}
