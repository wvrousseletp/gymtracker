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
  Function(int)? onWaterChanged;

  // Estados de erro/loading granular específicos por operação
  bool isSavingMeal = false;
  bool isSavingWater = false;
  bool isFastingUpdate = false;

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
    onWaterChanged?.call(quantityMl);
  }

  void addMeal(String name, int cals, double prot, double carbs, double fat,
      String time,
      {String? category}) {
    final meal = Meal(
      id: "meal-${DateTime.now().millisecondsSinceEpoch}-${diet.meals.length}",
      name: name,
      calories: cals,
      protein: prot,
      carbs: carbs,
      fat: fat,
      time: time,
      category: category ?? Meal.inferCategoryFromTime(time),
    );
    final meals = List<Meal>.from(diet.meals)..add(meal);

    diet = diet.copyWith(meals: meals);
    _save();
  }

  void updateMeal(
    String mealId, {
    required String name,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    required String time,
    String? category,
  }) {
    final idx = diet.meals.indexWhere((m) => m.id == mealId);
    if (idx == -1) return;
    final updatedMeals = List<Meal>.from(diet.meals);
    updatedMeals[idx] = updatedMeals[idx].copyWith(
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      time: time,
      category: category ?? updatedMeals[idx].effectiveCategory,
    );
    diet = diet.copyWith(meals: updatedMeals);
    _save();
  }

  DietHistoryDay? get latestHistoryDayWithMeals {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayKey =
        "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
    final yesterdayRecord = dietHistory[yesterdayKey];
    if (yesterdayRecord != null && yesterdayRecord.meals.isNotEmpty) {
      return yesterdayRecord;
    }

    final sortedKeys = dietHistory.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final k in sortedKeys) {
      final day = dietHistory[k];
      if (day != null && day.meals.isNotEmpty) {
        return day;
      }
    }
    return null;
  }

  /// Copia as refeições de ontem (ou do último dia com refeições registradas) para hoje.
  int copyPreviousDayMeals() {
    final source = latestHistoryDayWithMeals;
    if (source == null || source.meals.isEmpty) return 0;

    final baseTs = DateTime.now().millisecondsSinceEpoch;
    final copied = <Meal>[];
    for (int i = 0; i < source.meals.length; i++) {
      final m = source.meals[i];
      copied.add(m.copyWith(id: 'meal-$baseTs-$i'));
    }

    final merged = List<Meal>.from(diet.meals)..addAll(copied);
    diet = diet.copyWith(meals: merged);
    _save();
    return copied.length;
  }

  void deleteMeal(String mealId) {
    final meals = List<Meal>.from(diet.meals)
      ..removeWhere((m) => m.id == mealId);

    diet = diet.copyWith(meals: meals);
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
  void startFasting(double hours, {DateTime? startTime}) {
    final newFasting = FastingState(
      history: diet.fasting.history,
      active: ActiveFasting(
        startTime: (startTime ?? DateTime.now()).toUtc().toIso8601String(),
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

  void endFastingWithCustomTime(DateTime customEndTime) {
    if (diet.fasting.active == null) return;
    final active = diet.fasting.active!;

    final record = FastingRecord(
      id: "fast-${DateTime.now().millisecondsSinceEpoch}",
      startTime: active.startTime,
      endTime: customEndTime.toUtc().toIso8601String(),
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

  void addManualFastingRecord(DateTime startTime, DateTime endTime, double goalDurationHours) {
    final record = FastingRecord(
      id: "fast-${DateTime.now().millisecondsSinceEpoch}",
      startTime: startTime.toUtc().toIso8601String(),
      endTime: endTime.toUtc().toIso8601String(),
      goalDurationHours: goalDurationHours,
    );

    final history = List<FastingRecord>.from(diet.fasting.history)..insert(0, record);

    final newFasting = FastingState(
      history: history,
      active: diet.fasting.active,
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

  void addAbstinence(String title, [String? notes, String? customStartTime]) {
    final newRecord = AbstinenceRecord(
      id: "abst-${DateTime.now().millisecondsSinceEpoch}",
      title: title,
      startTime: customStartTime ?? DateTime.now().toUtc().toIso8601String(),
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
    
    // Force reset if lastDietDate is empty, invalid, or different from today
    if (diet.lastDietDate.isEmpty || diet.lastDietDate != todayStr) {
      // Only save history if lastDietDate is a valid date (not empty)
      if (diet.lastDietDate.isNotEmpty && _isValidDateFormat(diet.lastDietDate)) {
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
          meals: List<Meal>.from(diet.meals),
        );
        
        final newHistory = Map<String, DietHistoryDay>.from(dietHistory);
        newHistory[diet.lastDietDate] = historyDay;
        dietHistory = newHistory;
      }
      
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
      
      _save();
    }
  }

  bool _isValidDateFormat(String dateStr) {
    // Simple validation for YYYY-MM-DD format
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!regex.hasMatch(dateStr)) return false;
    
    try {
      final parts = dateStr.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      
      // Basic validation
      if (year < 2020 || year > 2100) return false;
      if (month < 1 || month > 12) return false;
      if (day < 1 || day > 31) return false;
      
      return true;
    } catch (_) {
      return false;
    }
  }
}
