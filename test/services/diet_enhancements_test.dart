import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker_flutter/models/diet.dart';
import 'package:gym_tracker_flutter/models/food_item.dart';
import 'package:gym_tracker_flutter/providers/diet_provider.dart';
import 'package:gym_tracker_flutter/services/food_service.dart';

void main() {
  group('FoodService accent-insensitive & substring search', () {
    final foods = [
      FoodItem(
        id: '1',
        name: 'Pão Francês Integral',
        searchName: 'pao frances integral',
        calories: 250,
        protein: 9.0,
        carbs: 48.0,
        fat: 2.5,
        servingSize: 100,
        servingUnit: 'g',
      ),
      FoodItem(
        id: '2',
        name: 'Feijão Carioca Cozido',
        searchName: 'feijao carioca cozido',
        calories: 76,
        protein: 4.8,
        carbs: 13.6,
        fat: 0.5,
        servingSize: 100,
        servingUnit: 'g',
      ),
      FoodItem(
        id: '3',
        name: 'Peito de Frango Grelhado',
        searchName: 'peito de frango grelhado',
        calories: 165,
        protein: 31.0,
        carbs: 0.0,
        fat: 3.6,
        servingSize: 100,
        servingUnit: 'g',
      ),
    ];

    test('encontra alimentos ignorando acentos e com busca por substring/multi-palavra', () {
      expect(FoodService.normalizeSearchText('Pão Francês'), 'pao frances');

      final pao = FoodService.filterFoodsLocally(foods, 'pao frances');
      expect(pao.map((f) => f.id), contains('1'));

      final feijao = FoodService.filterFoodsLocally(foods, 'feijao');
      expect(feijao.map((f) => f.id), contains('2'));

      final frango = FoodService.filterFoodsLocally(foods, 'frango grelhado');
      expect(frango.map((f) => f.id), contains('3'));
    });
  });

  group('DietProvider meal editing, categories & copyPreviousDayMeals', () {
    test('infere categoria pelo horário e permite editar refeição e copiar do dia anterior', () {
      expect(Meal.inferCategoryFromTime('08:30'), 'Café da Manhã');
      expect(Meal.inferCategoryFromTime('12:45'), 'Almoço');
      expect(Meal.inferCategoryFromTime('16:00'), 'Lanche');
      expect(Meal.inferCategoryFromTime('20:15'), 'Jantar');

      final dietProvider = DietProvider();
      dietProvider.dietHistory = {
        '2026-11-24': DietHistoryDay(
          date: '2026-11-24',
          caloriesIntake: 500,
          caloriesGoal: 2000,
          proteinIntake: 40,
          proteinGoal: 150,
          carbsIntake: 50,
          carbsGoal: 200,
          fatIntake: 12,
          fatGoal: 65,
          waterIntakeMl: 2000,
          waterGoalMl: 2500,
          meals: [
            Meal(
              id: 'old-1',
              name: 'Ovos Mexidos',
              calories: 300,
              protein: 24,
              carbs: 2,
              fat: 20,
              time: '08:00',
              category: 'Café da Manhã',
            ),
          ],
        ),
      };

      final copied = dietProvider.copyPreviousDayMeals();
      expect(copied, 1);
      expect(dietProvider.diet.meals.length, 1);
      final mealId = dietProvider.diet.meals.first.id;
      expect(dietProvider.diet.meals.first.effectiveCategory, 'Café da Manhã');

      dietProvider.updateMeal(
        mealId,
        name: 'Ovos Mexidos + Queijo',
        calories: 380,
        protein: 30,
        carbs: 3,
        fat: 25,
        time: '08:15',
        category: 'Lanche',
      );

      final updated = dietProvider.diet.meals.first;
      expect(updated.name, 'Ovos Mexidos + Queijo');
      expect(updated.calories, 380);
      expect(updated.effectiveCategory, 'Lanche');
    });
  });
}
