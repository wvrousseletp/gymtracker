import 'package:flutter/material.dart';
import '../models/diet.dart';
import '../models/profile.dart';
import 'profile_provider.dart';

class DietProvider extends ChangeNotifier {
  DietState diet = DietState(
    caloriesGoal: 2000,
    proteinGoal: 150.0,
    carbsGoal: 200.0,
    fatGoal: 70.0,
    waterGoalMl: 2000,
    meals: [],
    waterIntakeMl: 0,
    fasting: FastingState(history: []),
    abstinence: [],
  );
  
  Map<String, DietHistoryDay> dietHistory = {};

  String currentUserId = '';
  Profile? currentProfile;
  VoidCallback? onStateChanged;

  void updateProfile(ProfileProvider profileProvider) {
    currentUserId = profileProvider.currentUserId;
    currentProfile = profileProvider.currentProfile;
  }

  void _save() {
    notifyListeners();
    onStateChanged?.call();
  }

  // --- DIET & WATER OPERATIONS ---
  void updateWaterIntake(int quantityMl) {
    diet = DietState(
      caloriesGoal: diet.caloriesGoal,
      proteinGoal: diet.proteinGoal,
      carbsGoal: diet.carbsGoal,
      fatGoal: diet.fatGoal,
      waterGoalMl: diet.waterGoalMl,
      meals: diet.meals,
      waterIntakeMl: quantityMl,
      fasting: diet.fasting,
      abstinence: diet.abstinence,
      lastDietDate: diet.lastDietDate,
    );
    _save();
  }

  void addMeal(String name, int cals, double prot, double carbs, double fat, String time) {
    final meal = Meal(
      id: "meal-${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      calories: cals,
      protein: prot,
      carbs: carbs,
      fat: fat,
      time: time,
    );
    final meals = List<Meal>.from(diet.meals)..add(meal);
    
    diet = DietState(
      caloriesGoal: diet.caloriesGoal,
      proteinGoal: diet.proteinGoal,
      carbsGoal: diet.carbsGoal,
      fatGoal: diet.fatGoal,
      waterGoalMl: diet.waterGoalMl,
      meals: meals,
      waterIntakeMl: diet.waterIntakeMl,
      fasting: diet.fasting,
      abstinence: diet.abstinence,
      lastDietDate: diet.lastDietDate,
    );
    _save();
  }

  void deleteMeal(String mealId) {
    final meals = List<Meal>.from(diet.meals)..removeWhere((m) => m.id == mealId);
    
    diet = DietState(
      caloriesGoal: diet.caloriesGoal,
      proteinGoal: diet.proteinGoal,
      carbsGoal: diet.carbsGoal,
      fatGoal: diet.fatGoal,
      waterGoalMl: diet.waterGoalMl,
      meals: meals,
      waterIntakeMl: diet.waterIntakeMl,
      fasting: diet.fasting,
      abstinence: diet.abstinence,
      lastDietDate: diet.lastDietDate,
    );
    _save();
  }

  void updateDietGoals(int cals, double prot, double carbs, double fat) {
    diet = DietState(
      caloriesGoal: cals,
      proteinGoal: prot,
      carbsGoal: carbs,
      fatGoal: fat,
      waterGoalMl: diet.waterGoalMl,
      meals: diet.meals,
      waterIntakeMl: diet.waterIntakeMl,
      fasting: diet.fasting,
      abstinence: diet.abstinence,
      lastDietDate: diet.lastDietDate,
    );
    _save();
  }

  // --- FASTING ACTIONS ---
  void startFasting(double hours) {
    final newFasting = FastingState(
      history: diet.fasting.history,
      active: ActiveFasting(
        startTime: DateTime.now().toUtc().toIso8601String(),
        goalDurationHours: hours,
      ),
    );

    diet = DietState(
      caloriesGoal: diet.caloriesGoal,
      proteinGoal: diet.proteinGoal,
      carbsGoal: diet.carbsGoal,
      fatGoal: diet.fatGoal,
      waterGoalMl: diet.waterGoalMl,
      meals: diet.meals,
      waterIntakeMl: diet.waterIntakeMl,
      fasting: newFasting,
      abstinence: diet.abstinence,
      lastDietDate: diet.lastDietDate,
    );
    _save();
  }

  void endFasting() {
    if (diet.fasting.active == null) return;
    final active = diet.fasting.active!;

    final record = FastingRecord(
      id: "fast-${DateTime.now().millisecondsSinceEpoch}",
      startTime: active.startTime,
      endTime: DateTime.now().toUtc().toIso8601String(),
      goalDurationHours: active.goalDurationHours,
    );

    final history = List<FastingRecord>.from(diet.fasting.history)..insert(0, record);

    final newFasting = FastingState(
      history: history,
      active: null,
    );

    diet = DietState(
      caloriesGoal: diet.caloriesGoal,
      proteinGoal: diet.proteinGoal,
      carbsGoal: diet.carbsGoal,
      fatGoal: diet.fatGoal,
      waterGoalMl: diet.waterGoalMl,
      meals: diet.meals,
      waterIntakeMl: diet.waterIntakeMl,
      fasting: newFasting,
      abstinence: diet.abstinence,
      lastDietDate: diet.lastDietDate,
    );
    _save();
  }

  void updateWaterGoal(int goalMl) {
    diet = DietState(
      caloriesGoal: diet.caloriesGoal,
      proteinGoal: diet.proteinGoal,
      carbsGoal: diet.carbsGoal,
      fatGoal: diet.fatGoal,
      waterGoalMl: goalMl,
      meals: diet.meals,
      waterIntakeMl: diet.waterIntakeMl,
      fasting: diet.fasting,
      abstinence: diet.abstinence,
      lastDietDate: diet.lastDietDate,
    );
    _save();
  }

  void addAbstinence(String title, [String? notes]) {
    final newRecord = AbstinenceRecord(
      id: "abst-${DateTime.now().millisecondsSinceEpoch}",
      title: title,
      startTime: DateTime.now().toUtc().toIso8601String(),
      notes: notes,
    );
    final list = List<AbstinenceRecord>.from(diet.abstinence)..add(newRecord);
    diet = DietState(
      caloriesGoal: diet.caloriesGoal,
      proteinGoal: diet.proteinGoal,
      carbsGoal: diet.carbsGoal,
      fatGoal: diet.fatGoal,
      waterGoalMl: diet.waterGoalMl,
      meals: diet.meals,
      waterIntakeMl: diet.waterIntakeMl,
      fasting: diet.fasting,
      abstinence: list,
      lastDietDate: diet.lastDietDate,
    );
    _save();
  }

  void resetAbstinence(String id) {
    final list = diet.abstinence.map((a) {
      if (a.id == id) {
        return AbstinenceRecord(
          id: a.id,
          title: a.title,
          startTime: DateTime.now().toUtc().toIso8601String(),
          notes: a.notes,
        );
      }
      return a;
    }).toList();
    diet = DietState(
      caloriesGoal: diet.caloriesGoal,
      proteinGoal: diet.proteinGoal,
      carbsGoal: diet.carbsGoal,
      fatGoal: diet.fatGoal,
      waterGoalMl: diet.waterGoalMl,
      meals: diet.meals,
      waterIntakeMl: diet.waterIntakeMl,
      fasting: diet.fasting,
      abstinence: list,
      lastDietDate: diet.lastDietDate,
    );
    _save();
  }

  void deleteAbstinence(String id) {
    final list = List<AbstinenceRecord>.from(diet.abstinence)..removeWhere((a) => a.id == id);
    diet = DietState(
      caloriesGoal: diet.caloriesGoal,
      proteinGoal: diet.proteinGoal,
      carbsGoal: diet.carbsGoal,
      fatGoal: diet.fatGoal,
      waterGoalMl: diet.waterGoalMl,
      meals: diet.meals,
      waterIntakeMl: diet.waterIntakeMl,
      fasting: diet.fasting,
      abstinence: list,
      lastDietDate: diet.lastDietDate,
    );
    _save();
  }

  void checkAndResetDailyDiet() {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    if (diet.lastDietDate != todayStr) {
      int totalCals = diet.meals.fold<int>(0, (sum, m) => sum + m.calories);
      double totalProt = diet.meals.fold<double>(0, (sum, m) => sum + m.protein);
      double totalCarbs = diet.meals.fold<double>(0, (sum, m) => sum + m.carbs);
      double totalFat = diet.meals.fold<double>(0, (sum, m) => sum + m.fat);
      
      final historyDay = DietHistoryDay(
        date: diet.lastDietDate,
        caloriesGoal: diet.caloriesGoal,
        caloriesIntake: totalCals,
        proteinGoal: diet.proteinGoal,
        proteinIntake: totalProt,
        carbsGoal: diet.carbsGoal,
        carbsIntake: totalCarbs,
        fatGoal: diet.fatGoal,
        fatIntake: totalFat,
        waterGoalMl: diet.waterGoalMl,
        waterIntakeMl: diet.waterIntakeMl,
      );
      
      final newHistory = Map<String, DietHistoryDay>.from(dietHistory);
      newHistory[diet.lastDietDate] = historyDay;
      
      diet = DietState(
        caloriesGoal: diet.caloriesGoal,
        proteinGoal: diet.proteinGoal,
        carbsGoal: diet.carbsGoal,
        fatGoal: diet.fatGoal,
        waterGoalMl: diet.waterGoalMl,
        meals: [],
        waterIntakeMl: 0,
        fasting: diet.fasting,
        abstinence: diet.abstinence,
        lastDietDate: todayStr,
      );
      
      dietHistory = newHistory;
      _save();
    }
  }
}
