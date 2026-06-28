class FoodItem {
  final String id;
  final String name;
  final String searchName;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final int servingSize; // standard serving e.g. 100
  final String servingUnit; // g, ml, unidade

  FoodItem({
    required this.id,
    required this.name,
    required this.searchName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    required this.servingUnit,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'searchName': searchName,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'servingSize': servingSize,
    'servingUnit': servingUnit,
  };

  factory FoodItem.fromJson(Map<String, dynamic> json, String docId) => FoodItem(
    id: docId,
    name: json['name'] ?? '',
    searchName: json['searchName'] ?? '',
    calories: (json['calories'] as num?)?.toInt() ?? 0,
    protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
    carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
    fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
    servingSize: (json['servingSize'] as num?)?.toInt() ?? 100,
    servingUnit: json['servingUnit'] ?? 'g',
  );
}
