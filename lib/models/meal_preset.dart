import 'food_item.dart';

class MealPresetItem {
  final FoodItem food;
  final double quantity;

  MealPresetItem({
    required this.food,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
        'food': food.toJson(),
        'quantity': quantity,
      };

  factory MealPresetItem.fromJson(Map<String, dynamic> json) => MealPresetItem(
        food: FoodItem.fromJson(json['food'] ?? {}, ''),
        quantity: (json['quantity'] as num?)?.toDouble() ?? 100.0,
      );
}

class MealPreset {
  final String id;
  final String name;
  final List<MealPresetItem> items;

  MealPreset({
    required this.id,
    required this.name,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory MealPreset.fromJson(Map<String, dynamic> json, String docId) => MealPreset(
        id: docId,
        name: json['name'] ?? '',
        items: json['items'] != null
            ? (json['items'] as List).map((i) => MealPresetItem.fromJson(i)).toList()
            : [],
      );

  // Calcula macros totais do preset
  int get totalCalories {
    return items.fold(0, (sum, item) {
      final scale = item.quantity / item.food.servingSize;
      return sum + (item.food.calories * scale).round();
    });
  }

  double get totalProtein {
    return items.fold(0.0, (sum, item) {
      final scale = item.quantity / item.food.servingSize;
      return sum + (item.food.protein * scale);
    });
  }

  double get totalCarbs {
    return items.fold(0.0, (sum, item) {
      final scale = item.quantity / item.food.servingSize;
      return sum + (item.food.carbs * scale);
    });
  }

  double get totalFat {
    return items.fold(0.0, (sum, item) {
      final scale = item.quantity / item.food.servingSize;
      return sum + (item.food.fat * scale);
    });
  }
}
