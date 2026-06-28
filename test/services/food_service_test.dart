import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker_flutter/models/food_item.dart';
import 'package:gym_tracker_flutter/models/meal_preset.dart';

void main() {
  group('Cálculo Proporcional de Alimentos (Macros e Calorias)', () {
    final mockFood = FoodItem(
      id: 'mock_123',
      name: 'Peito de Frango Grelhado',
      searchName: 'peito de frango grelhado',
      calories: 165,
      protein: 31.0,
      carbs: 0.0,
      fat: 3.6,
      servingSize: 100,
      servingUnit: 'g',
    );

    test('Cálculo correto para porção de 150g (escala 1.5)', () {
      const quantity = 150.0;
      final scale = quantity / mockFood.servingSize;

      final calories = (mockFood.calories * scale).round();
      final protein = double.parse((mockFood.protein * scale).toStringAsFixed(1));
      final carbs = double.parse((mockFood.carbs * scale).toStringAsFixed(1));
      final fat = double.parse((mockFood.fat * scale).toStringAsFixed(1));

      expect(calories, equals(248)); // 165 * 1.5 = 247.5 -> round = 248
      expect(protein, equals(46.5)); // 31 * 1.5 = 46.5
      expect(carbs, equals(0.0));
      expect(fat, equals(5.4)); // 3.6 * 1.5 = 5.4
    });

    test('Cálculo correto para porção de 50g (escala 0.5)', () {
      const quantity = 50.0;
      final scale = quantity / mockFood.servingSize;

      final calories = (mockFood.calories * scale).round();
      final protein = double.parse((mockFood.protein * scale).toStringAsFixed(1));
      final carbs = double.parse((mockFood.carbs * scale).toStringAsFixed(1));
      final fat = double.parse((mockFood.fat * scale).toStringAsFixed(1));

      expect(calories, equals(83)); // 165 * 0.5 = 82.5 -> round = 83
      expect(protein, equals(15.5)); // 31 * 0.5 = 15.5
      expect(carbs, equals(0.0));
      expect(fat, equals(1.8)); // 3.6 * 0.5 = 1.8
    });
  });

  group('Combos / Presets de Alimentos', () {
    test('Cálculo de macros totais do combo', () {
      final banana = FoodItem(id: '', name: 'Banana', searchName: 'banana', calories: 90, protein: 1.0, carbs: 22.0, fat: 0.3, servingSize: 100, servingUnit: 'g');
      final whey = FoodItem(id: '', name: 'Whey Protein', searchName: 'whey protein', calories: 120, protein: 24.0, carbs: 3.0, fat: 1.5, servingSize: 30, servingUnit: 'g');

      final combo = MealPreset(
        id: 'combo_1',
        name: 'Meu Shake Pós-Treino',
        items: [
          MealPresetItem(food: banana, quantity: 150.0), // 1.5x -> cals=135, prot=1.5, carbs=33, fat=0.45
          MealPresetItem(food: whey, quantity: 30.0),    // 1.0x -> cals=120, prot=24, carbs=3, fat=1.5
        ],
      );

      expect(combo.totalCalories, equals(255)); // 135 + 120
      expect(combo.totalProtein, closeTo(25.5, 0.01)); // 1.5 + 24
      expect(combo.totalCarbs, closeTo(36.0, 0.01)); // 33 + 3
      expect(combo.totalFat, closeTo(1.95, 0.01)); // 0.45 + 1.5
    });
  });
}
