import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/diet_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';
import '../models/diet.dart';
import '../models/food_item.dart';
import '../models/favorite_food.dart';
import '../models/meal_preset.dart';
import '../services/food_service.dart';
import '../services/ai_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileProvider = Provider.of<ProfileProvider>(context);
    final accentColor = ThemeUtils.getAdaptiveColor(
      profileProvider.currentProfile.colorAccent,
      isDark: isDark,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: accentColor,
              labelColor: isDark ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
              unselectedLabelColor:
                  isDark ? (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93)) : const Color(0xFF8E8E93),
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: "Refeições"),
                Tab(text: "Água"),
                Tab(text: "Jejum"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefeicoesTab(accentColor: accentColor),
                AguaTab(accentColor: accentColor),
                JejumTab(accentColor: accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. REFEIÇÕES TAB
// ==========================================
class RefeicoesTab extends StatelessWidget {
  final Color accentColor;
  const RefeicoesTab({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final dietProvider = Provider.of<DietProvider>(context);
    final trackerProvider = Provider.of<TrackerProvider>(context);
    final provider = trackerProvider;
    final diet = dietProvider.diet;

    // Cálculos
    int totalCals = diet.meals.fold<int>(0, (sum, m) => sum + m.calories);
    int activeCals = provider.todayBurnedCalories;
    int netCals = totalCals - activeCals;
    if (netCals < 0) netCals = 0;

    double totalProt = diet.meals.fold<double>(0, (sum, m) => sum + m.protein);
    double totalCarbs = diet.meals.fold<double>(0, (sum, m) => sum + m.carbs);
    double totalFat = diet.meals.fold<double>(0, (sum, m) => sum + m.fat);

    final netProgress = diet.caloriesGoal > 0
        ? (netCals / diet.caloriesGoal).clamp(0.0, 1.0)
        : 0.0;
    final protProgress = diet.proteinGoal > 0
        ? (totalProt / diet.proteinGoal).clamp(0.0, 1.0)
        : 0.0;
    final carbsProgress = diet.carbsGoal > 0
        ? (totalCarbs / diet.carbsGoal).clamp(0.0, 1.0)
        : 0.0;
    final fatProgress =
        diet.fatGoal > 0 ? (totalFat / diet.fatGoal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          onPressed: () {
            _openAddMealDialog(context, dietProvider);
          },
          backgroundColor: accentColor,
          mini: true,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
      body: RefreshIndicator(
        color: accentColor,
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
        onRefresh: () async {
          provider.checkAndResetDailyDiet();
          await provider.syncHealthMetrics();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resumo de Calorias & Macros
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.04),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Saldo Líquido de Calorias",
                                      style: TextStyle(
                                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                    "$netCals / ${diet.caloriesGoal} kcal",
                                    style: TextStyle(
                                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Consumido: $totalCals kcal • Ativo: $activeCals kcal",
                                    style: TextStyle(
                                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93)),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text(
                                "${(netProgress * 100).toStringAsFixed(0)}%",
                                style: TextStyle(
                                    color: accentColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: netProgress,
                            backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(accentColor),
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 8,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                  child: _buildMacroBar(
                                      "Proteínas",
                                      totalProt,
                                      diet.proteinGoal,
                                      protProgress,
                                      const Color(0xffff453a))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _buildMacroBar(
                                      "Carboidratos",
                                      totalCarbs,
                                      diet.carbsGoal,
                                      carbsProgress,
                                      const Color(0xffbf5af2))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _buildMacroBar(
                                      "Gorduras",
                                      totalFat,
                                      diet.fatGoal,
                                      fatProgress,
                                      const Color(0xffff9f0a))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // HealthKit Summary / Opt-in Card
                    if (provider.healthAuthorized) ...[
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.04),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text("🔥",
                                    style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Gasto Ativo",
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${provider.todayBurnedCalories} kcal",
                                      style: TextStyle(
                                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Text("🚶",
                                    style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Passos",
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${provider.todaySteps}",
                                      style: TextStyle(
                                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Text("❤️",
                                    style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Frequência",
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(
                                      provider.currentHeartRate > 0
                                          ? "${provider.currentHeartRate} bpm"
                                          : "--",
                                      style: TextStyle(
                                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      GestureDetector(
                        onTap: () => provider.requestHealthAuthorization(),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          borderColor: accentColor.withOpacity(0.3),
                          child: Row(
                            children: [
                              Icon(Icons.favorite,
                                  color: accentColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Conectar com App Saúde",
                                      style: TextStyle(
                                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Acompanhe calorias ativas, passos e batimentos cardíacos.",
                                      style: TextStyle(
                                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73))),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Refeições do Dia",
                          style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                              fontSize: 15,
                              fontWeight: FontWeight.w800),
                        ),
                        if (dietProvider.latestHistoryDayWithMeals != null)
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              final copied =
                                  dietProvider.copyPreviousDayMeals();
                              if (copied > 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '$copied refeição(ões) copiada(s) do último registro!'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: accentColor.withOpacity(0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.history_rounded,
                                      size: 14, color: accentColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Repetir Ontem",
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (diet.meals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            "Nenhuma refeição registrada hoje.",
                            style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93)),
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Meals grouped by category (Café da Manhã, Almoço, Lanche, Jantar)
            if (diet.meals.isNotEmpty)
              SliverPadding(
                padding:
                    const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    _buildGroupedMealsWidgets(context, dietProvider, provider, diet.meals),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Café da Manhã':
        return Icons.wb_twilight_rounded;
      case 'Almoço':
        return Icons.wb_sunny_outlined;
      case 'Lanche':
        return Icons.apple_rounded;
      case 'Jantar':
        return Icons.nights_stay_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  List<Widget> _buildGroupedMealsWidgets(
    BuildContext context,
    DietProvider dietProvider,
    TrackerProvider provider,
    List<Meal> meals,
  ) {
    final orderedCategories = <String>[
      ...Meal.categories,
      ...meals
          .map((m) => m.effectiveCategory)
          .where((c) => !Meal.categories.contains(c))
          .toSet(),
    ];

    final List<Widget> widgets = [];
    for (final cat in orderedCategories) {
      final catMeals =
          meals.where((m) => m.effectiveCategory == cat).toList();
      if (catMeals.isEmpty) continue;

      final catCals = catMeals.fold<int>(0, (s, m) => s + m.calories);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(_categoryIcon(cat),
                      size: 14, color: accentColor.withOpacity(0.9)),
                  const SizedBox(width: 6),
                  Text(
                    cat,
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Text(
                "$catCals kcal",
                style: TextStyle(
                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );

      for (final meal in catMeals) {
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => _showEditMealDialog(context, dietProvider, meal),
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.04),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  meal.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                meal.time,
                                style: TextStyle(
                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93)), fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildMiniMacroLabel(
                                  "P", meal.protein, const Color(0xffff453a)),
                              const SizedBox(width: 8),
                              _buildMiniMacroLabel(
                                  "C", meal.carbs, const Color(0xffbf5af2)),
                              const SizedBox(width: 8),
                              _buildMiniMacroLabel(
                                  "G", meal.fat, const Color(0xffff9f0a)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        Text(
                          "${meal.calories} kcal",
                          style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                              fontWeight: FontWeight.w900,
                              fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              _showEditMealDialog(context, dietProvider, meal),
                          child: Icon(Icons.edit_outlined,
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93)), size: 17),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            provider.deleteMeal(meal.id);
                          },
                          child: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  void _showEditMealDialog(
      BuildContext context, DietProvider dietProvider, Meal meal) {
    final nameCtrl = TextEditingController(text: meal.name);
    final calsCtrl = TextEditingController(text: meal.calories.toString());
    final protCtrl =
        TextEditingController(text: meal.protein.toStringAsFixed(1));
    final carbsCtrl =
        TextEditingController(text: meal.carbs.toStringAsFixed(1));
    final fatCtrl = TextEditingController(text: meal.fat.toStringAsFixed(1));
    final timeCtrl = TextEditingController(text: meal.time);
    String selectedCat = meal.effectiveCategory;

    InputDecoration inputDeco(String label) => InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), fontSize: 11),
          filled: true,
          fillColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        );

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            useBlur: true,
            borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
            borderRadius: 20,
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Editar Refeição",
                          style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                              fontWeight: FontWeight.w800,
                              fontSize: 16),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), size: 20),
                          onPressed: () => Navigator.pop(dialogCtx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: Meal.categories.map((cat) {
                        final isSel = selectedCat == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSel,
                          onSelected: (v) {
                            if (v) setDialogState(() => selectedCat = cat);
                          },
                          selectedColor: accentColor.withOpacity(0.25),
                          backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                          labelStyle: TextStyle(
                            color: isSel ? accentColor : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)),
                            fontSize: 11,
                            fontWeight:
                                isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 13),
                      decoration: inputDeco("Alimento / Refeição"),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: calsCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 12),
                            decoration: inputDeco("Calorias (kcal)"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: timeCtrl,
                            style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 12),
                            decoration: inputDeco("Horário (HH:MM)"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: protCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 12),
                            decoration: inputDeco("Prot (g)"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: carbsCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 12),
                            decoration: inputDeco("Carbs (g)"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: fatCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 12),
                            decoration: inputDeco("Gord (g)"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: Text("Cancelar",
                              style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)))),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final newName = nameCtrl.text.trim();
                            if (newName.isEmpty) return;
                            final newCals =
                                int.tryParse(calsCtrl.text.trim()) ??
                                    meal.calories;
                            final newProt = double.tryParse(protCtrl.text
                                    .trim()
                                    .replaceAll(',', '.')) ??
                                meal.protein;
                            final newCarbs = double.tryParse(carbsCtrl.text
                                    .trim()
                                    .replaceAll(',', '.')) ??
                                meal.carbs;
                            final newFat = double.tryParse(
                                    fatCtrl.text.trim().replaceAll(',', '.')) ??
                                meal.fat;
                            final newTime = timeCtrl.text.trim().isNotEmpty
                                ? timeCtrl.text.trim()
                                : meal.time;

                            dietProvider.updateMeal(
                              meal.id,
                              name: newName,
                              calories: newCals,
                              protein: newProt,
                              carbs: newCarbs,
                              fat: newFat,
                              time: newTime,
                              category: selectedCat,
                            );
                            Navigator.pop(dialogCtx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Salvar",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMacroBar(
      String name, double val, double goal, double progress, Color color) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF6E6E73),
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              "${val.toStringAsFixed(1)}/${goal.toStringAsFixed(0)}g",
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              borderRadius: BorderRadius.circular(2),
              minHeight: 4,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiniMacroLabel(String letter, double val, Color color) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Row(
          children: [
            Text(
              letter,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 2),
            Text(
              "${val.toStringAsFixed(1)}g",
              style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF3C3C43),
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
          ],
        );
      },
    );
  }

  void _openAddMealDialog(BuildContext context, DietProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => _AddMealDialogContent(
        provider: provider,
        accentColor: accentColor,
      ),
    );
  }
}

class _AddMealDialogContent extends StatefulWidget {
  final DietProvider provider;
  final Color accentColor;

  const _AddMealDialogContent({
    required this.provider,
    required this.accentColor,
  });

  @override
  State<_AddMealDialogContent> createState() => _AddMealDialogContentState();
}

class _AddMealDialogContentState extends State<_AddMealDialogContent> {
  final FoodService _foodService = FoodService.instance;
  final _searchCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: "100");

  final _manualNameCtrl = TextEditingController();
  final _manualCalsCtrl = TextEditingController();
  final _manualProtCtrl = TextEditingController();
  final _manualCarbsCtrl = TextEditingController();
  final _manualFatCtrl = TextEditingController();

  // Abas do dialog: 0 = Busca/IA, 1 = Favoritos, 2 = Refeições Salvas
  int _activeTab = 0;

  List<FavoriteFood> _favorites = [];
  List<MealPreset> _presets = [];
  bool _loadingFavsOrPresets = false;

  // Variáveis para criação de combo
  bool _isCreatingCombo = false;
  final _comboNameCtrl = TextEditingController();
  final _comboSearchCtrl = TextEditingController();
  List<FoodItem> _comboSearchResults = [];
  List<MealPresetItem> _newComboItems = [];

  List<FoodItem> _searchResults = [];
  bool _isLoading = false;
  bool _isEstimatingAI = false;
  String? _errorMessage;

  FoodItem? _selectedFood;
  bool _isManualMode = false;

  Timer? _searchDebounce;
  Timer? _comboSearchDebounce;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final nowStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    _selectedCategory = Meal.inferCategoryFromTime(nowStr);
    _loadFavoritesAndPresets();
  }

  void _loadFavoritesAndPresets() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    setState(() => _loadingFavsOrPresets = true);
    try {
      final favs = await _foodService.getFavorites(userId);
      final prets = await _foodService.getPresets(userId);
      if (!mounted) return;
      setState(() {
        _favorites = favs;
        _presets = prets;
        _loadingFavsOrPresets = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFavsOrPresets = false);
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedFood = null;
      _isManualMode = false;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final results = await _foodService.searchFoods(query);
        if (!mounted || _searchCtrl.text.trim() != query) return;
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = "Erro ao buscar alimentos.";
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _estimateWithAI() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _errorMessage =
            "Descreva o que você comeu acima (ex: 2 ovos mexidos com pão francês) e toque em Estimar com IA.";
      });
      return;
    }

    _searchDebounce?.cancel();
    setState(() {
      _isEstimatingAI = true;
      _isLoading = false;
      _errorMessage = null;
      _searchResults = [];
      _isManualMode = false;
    });

    final estimated = await AIService().estimateMealMacros(query);
    if (!mounted) return;

    if (estimated == null) {
      setState(() {
        _isEstimatingAI = false;
        _errorMessage =
            "Não foi possível estimar os macros com IA no momento. Tente novamente ou use o modo manual.";
      });
      return;
    }

    setState(() {
      _isEstimatingAI = false;
    });
    _selectFood(estimated);
  }

  void _selectFood(FoodItem food) {
    setState(() {
      _selectedFood = food;
      _quantityCtrl.text = food.servingSize.round().toString();
      _searchResults = [];
      _searchCtrl.text = food.name;
    });
  }

  void _switchToManual() {
    setState(() {
      _isManualMode = true;
      _selectedFood = null;
      _searchResults = [];
      _manualNameCtrl.text = _searchCtrl.text;
      _manualCalsCtrl.text = "";
      _manualProtCtrl.text = "";
      _manualCarbsCtrl.text = "";
      _manualFatCtrl.text = "";
    });
  }

  void _addCurrentToFavorites() async {
    if (_selectedFood == null) return;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    final qty = double.tryParse(_quantityCtrl.text.trim()) ??
        _selectedFood!.servingSize.toDouble();

    // Se for um alimento retornado pela IA sem ID no banco global, cadastramos globalmente antes de favoritar
    if (_selectedFood!.id.isEmpty) {
      final assignedId = 'ai-${DateTime.now().millisecondsSinceEpoch}';
      final persisted = FoodItem(
        id: assignedId,
        name: _selectedFood!.name,
        searchName: _selectedFood!.searchName,
        calories: _selectedFood!.calories,
        protein: _selectedFood!.protein,
        carbs: _selectedFood!.carbs,
        fat: _selectedFood!.fat,
        servingSize: _selectedFood!.servingSize,
        servingUnit: _selectedFood!.servingUnit,
      );
      await _foodService.addFood(persisted);
      _selectedFood = persisted;
    }

    final fav = FavoriteFood(
      id: 'fav-${DateTime.now().millisecondsSinceEpoch}',
      food: _selectedFood!,
      favoriteQuantity: qty,
    );
    await _foodService.addFavorite(userId, fav);
    _loadFavoritesAndPresets();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Alimento adicionado aos favoritos! ⭐")),
    );
  }

  void _deleteFavorite(String favId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    await _foodService.deleteFavorite(userId, favId);
    _loadFavoritesAndPresets();
  }

  void _registerFavoriteMeal(FavoriteFood fav) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final scale = fav.favoriteQuantity / fav.food.servingSize;

    final name = fav.food.name;
    final calories = (fav.food.calories * scale).round();
    final protein = double.parse((fav.food.protein * scale).toStringAsFixed(1));
    final carbs = double.parse((fav.food.carbs * scale).toStringAsFixed(1));
    final fat = double.parse((fav.food.fat * scale).toStringAsFixed(1));

    widget.provider.addMeal(name, calories, protein, carbs, fat, timeStr,
        category: _selectedCategory);
    Navigator.pop(context);
  }

  // --- MÉTODOS DE REFEIÇÕES SALVAS/PRESETS ---

  void _onComboSearchChanged() {
    _comboSearchDebounce?.cancel();
    final query = _comboSearchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() => _comboSearchResults = []);
      return;
    }
    _comboSearchDebounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final results = await _foodService.searchFoods(query);
        if (!mounted || _comboSearchCtrl.text.trim() != query) return;
        setState(() => _comboSearchResults = results);
      } catch (e) {
        debugPrint("Erro ao buscar alimento para a refeição: $e");
      }
    });
  }

  void _addItemToNewCombo(FoodItem food) {
    setState(() {
      _newComboItems.add(
          MealPresetItem(food: food, quantity: food.servingSize.toDouble()));
      _comboSearchCtrl.clear();
      _comboSearchResults = [];
    });
  }

  void _removeItemFromNewCombo(int index) {
    setState(() {
      _newComboItems.removeAt(index);
    });
  }

  void _saveNewCombo() async {
    final name = _comboNameCtrl.text.trim();
    if (name.isEmpty || _newComboItems.isEmpty) return;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final preset = MealPreset(
      id: 'preset-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      items: _newComboItems,
    );

    await _foodService.addPreset(userId, preset);
    setState(() {
      _isCreatingCombo = false;
      _comboNameCtrl.clear();
      _newComboItems = [];
    });
    _loadFavoritesAndPresets();
  }

  void _deletePreset(String presetId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    await _foodService.deletePreset(userId, presetId);
    _loadFavoritesAndPresets();
  }

  void _registerPresetMeal(MealPreset preset) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    for (final item in preset.items) {
      final scale = item.quantity / item.food.servingSize;
      final name = item.food.name;
      final calories = (item.food.calories * scale).round();
      final protein =
          double.parse((item.food.protein * scale).toStringAsFixed(1));
      final carbs = double.parse((item.food.carbs * scale).toStringAsFixed(1));
      final fat = double.parse((item.food.fat * scale).toStringAsFixed(1));

      widget.provider.addMeal(name, calories, protein, carbs, fat, timeStr,
          category: _selectedCategory);
    }
    Navigator.pop(context);
  }

  void _registerMeal() async {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    if (_isManualMode) {
      final name = _manualNameCtrl.text.trim();
      if (name.isEmpty) return;

      final calories = int.tryParse(_manualCalsCtrl.text.trim()) ?? 0;
      final protein =
          double.tryParse(_manualProtCtrl.text.trim().replaceAll(',', '.')) ??
              0.0;
      final carbs =
          double.tryParse(_manualCarbsCtrl.text.trim().replaceAll(',', '.')) ??
              0.0;
      final fat =
          double.tryParse(_manualFatCtrl.text.trim().replaceAll(',', '.')) ??
              0.0;

      widget.provider.addMeal(name, calories, protein, carbs, fat, timeStr,
          category: _selectedCategory);
      Navigator.pop(context);
    } else if (_selectedFood != null) {
      // Se for um alimento novo vindo da IA (ID vazio), salvamos no Firestore global
      if (_selectedFood!.id.isEmpty) {
        final assignedId = 'ai-${DateTime.now().millisecondsSinceEpoch}';
        final persisted = FoodItem(
          id: assignedId,
          name: _selectedFood!.name,
          searchName: _selectedFood!.searchName,
          calories: _selectedFood!.calories,
          protein: _selectedFood!.protein,
          carbs: _selectedFood!.carbs,
          fat: _selectedFood!.fat,
          servingSize: _selectedFood!.servingSize,
          servingUnit: _selectedFood!.servingUnit,
        );
        await _foodService.addFood(persisted);
        _selectedFood = persisted;
      }

      final quantity = double.tryParse(_quantityCtrl.text.trim()) ??
          _selectedFood!.servingSize.toDouble();
      final scale = quantity / _selectedFood!.servingSize;

      final name = _selectedFood!.name;
      final calories = (_selectedFood!.calories * scale).round();
      final protein =
          double.parse((_selectedFood!.protein * scale).toStringAsFixed(1));
      final carbs =
          double.parse((_selectedFood!.carbs * scale).toStringAsFixed(1));
      final fat = double.parse((_selectedFood!.fat * scale).toStringAsFixed(1));

      widget.provider.addMeal(name, calories, protein, carbs, fat, timeStr,
          category: _selectedCategory);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _comboSearchDebounce?.cancel();
    _searchCtrl.dispose();
    _quantityCtrl.dispose();
    _manualNameCtrl.dispose();
    _manualCalsCtrl.dispose();
    _manualProtCtrl.dispose();
    _manualCarbsCtrl.dispose();
    _manualFatCtrl.dispose();
    _comboNameCtrl.dispose();
    _comboSearchCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dialogInputDeco(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
      hintText: hint,
      hintStyle: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white30 : const Color(0xFFAEAEB2)), fontSize: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05)),
      ),
      child: Row(
        children: [
          _tabHeaderItem(0, "Busca / IA", Icons.search),
          _tabHeaderItem(1, "Favoritos", Icons.star),
          _tabHeaderItem(2, "Refeições Salvas", Icons.brunch_dining),
        ],
      ),
    );
  }

  Widget _tabHeaderItem(int index, String title, IconData icon) {
    final active = _activeTab == index;
    final accentColor = widget.accentColor;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = index;
            _selectedFood = null;
            _isManualMode = false;
            _isCreatingCombo = false;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? accentColor.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 16, color: active ? accentColor : (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93))),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  color: active ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93)),
                  fontSize: 10,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        useBlur: true,
        borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
        borderRadius: 20,
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Registrar Refeição",
                    style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), size: 20),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
                      padding: const EdgeInsets.all(4),
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: Meal.categories.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSel,
                        onSelected: (v) {
                          if (v) setState(() => _selectedCategory = cat);
                        },
                        selectedColor: accentColor.withOpacity(0.25),
                        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                        visualDensity: VisualDensity.compact,
                        labelStyle: TextStyle(
                          color: isSel ? accentColor : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)),
                          fontSize: 10,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTabs(),
                      if (_activeTab == 0) ...[
                        TextField(
                          controller: _searchCtrl,
                          style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 14),
                          decoration: _dialogInputDeco(
                              "Buscar ou descrever refeição p/ IA..."),
                          onChanged: (_) => _onSearchChanged(),
                        ),
                        const SizedBox(height: 10),
                        if (_errorMessage != null) ...[
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_isLoading || _isEstimatingAI) ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Column(
                                children: [
                                  CircularProgressIndicator(
                                      color: _isEstimatingAI
                                          ? accentColor
                                          : Colors.white),
                                  if (_isEstimatingAI) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      "Estimando macros com IA...",
                                      style: TextStyle(
                                          color: accentColor, fontSize: 11),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (!_isLoading &&
                            !_isEstimatingAI &&
                            _searchResults.isNotEmpty) ...[
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.03),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const ClampingScrollPhysics(),
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) => Divider(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                                  height: 1),
                              itemBuilder: (context, index) {
                                final item = _searchResults[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(item.name,
                                      style: TextStyle(
                                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  subtitle: Text(
                                    "${item.calories} kcal | P: ${item.protein}g | C: ${item.carbs}g | G: ${item.fat}g por ${item.servingSize.round()}g",
                                    style: TextStyle(
                                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : const Color(0xFF48484A)), fontSize: 11),
                                  ),
                                  onTap: () => _selectFood(item),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _isEstimatingAI ? null : _estimateWithAI,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: accentColor.withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.auto_awesome,
                                          color: accentColor, size: 15),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          "Estimar com IA",
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: accentColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: _switchToManual,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.edit_note_rounded,
                                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), size: 16),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          "Modo Manual",
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_selectedFood != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.06)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedFood!.name,
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.star_border,
                                          color: Colors.amber, size: 18),
                                      onPressed: _addCurrentToFavorites,
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _quantityCtrl,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 13),
                                        decoration: _dialogInputDeco(
                                            "Quantidade (g ou ml)"),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Informações Nutricionais Proporcionais
                                Builder(
                                  builder: (context) {
                                    final qty = double.tryParse(
                                            _quantityCtrl.text.trim()) ??
                                        _selectedFood!.servingSize.toDouble();
                                    final scale =
                                        qty / _selectedFood!.servingSize;
                                    final calories =
                                        (_selectedFood!.calories * scale)
                                            .round();
                                    final protein =
                                        _selectedFood!.protein * scale;
                                    final carbs = _selectedFood!.carbs * scale;
                                    final fat = _selectedFood!.fat * scale;

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Total: $calories kcal",
                                          style: TextStyle(
                                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _macroBadge(
                                                "P",
                                                "${protein.toStringAsFixed(1)}g",
                                                const Color(0xffff453a)),
                                            _macroBadge(
                                                "C",
                                                "${carbs.toStringAsFixed(1)}g",
                                                const Color(0xffbf5af2)),
                                            _macroBadge(
                                                "G",
                                                "${fat.toStringAsFixed(1)}g",
                                                const Color(0xffff9f0a)),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_isManualMode) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.06)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Modo Manual ✍️",
                                  style: TextStyle(
                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _manualNameCtrl,
                                  style: TextStyle(
                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 13),
                                  decoration:
                                      _dialogInputDeco("Nome do alimento..."),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _manualCalsCtrl,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 12),
                                        decoration:
                                            _dialogInputDeco("Calorias (kcal)"),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _manualProtCtrl,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 12),
                                        decoration:
                                            _dialogInputDeco("Prot (g)"),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _manualCarbsCtrl,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 12),
                                        decoration:
                                            _dialogInputDeco("Carbs (g)"),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _manualFatCtrl,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 12),
                                        decoration:
                                            _dialogInputDeco("Gord (g)"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      if (_activeTab == 1) ...[
                        if (_loadingFavsOrPresets)
                          const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.amber))
                        else if (_favorites.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                "Nenhum favorito salvo ainda.",
                                style: TextStyle(
                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93)), fontSize: 12),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _favorites.length,
                            separatorBuilder: (_, __) => Divider(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                                height: 1),
                            itemBuilder: (context, index) {
                              final fav = _favorites[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(fav.food.name,
                                    style: TextStyle(
                                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                subtitle: Text(
                                  "${fav.favoriteQuantity.round()}g | ${(fav.food.calories * (fav.favoriteQuantity / fav.food.servingSize)).round()} kcal",
                                  style: TextStyle(
                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : const Color(0xFF48484A)), fontSize: 11),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.star,
                                      color: Colors.amber, size: 16),
                                  onPressed: () => _deleteFavorite(fav.id),
                                ),
                                onTap: () => _registerFavoriteMeal(fav),
                              );
                            },
                          ),
                      ],
                      if (_activeTab == 2) ...[
                        if (_isCreatingCombo) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _comboNameCtrl,
                                  style: TextStyle(
                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 13),
                                  decoration: _dialogInputDeco(
                                      "Nome da refeição (ex: Café da Manhã)"),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.redAccent),
                                onPressed: () =>
                                    setState(() => _isCreatingCombo = false),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_newComboItems.isNotEmpty)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _newComboItems.length,
                              itemBuilder: (context, idx) {
                                final item = _newComboItems[idx];
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "${item.food.name} (${item.quantity.round()}g) - ${(item.food.calories * (item.quantity / item.food.servingSize)).round()} kcal",
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)),
                                            fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.redAccent,
                                          size: 16),
                                      onPressed: () =>
                                          _removeItemFromNewCombo(idx),
                                    ),
                                  ],
                                );
                              },
                            ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _comboSearchCtrl,
                            style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 12),
                            decoration: _dialogInputDeco(
                                "Buscar e adicionar alimento..."),
                            onChanged: (_) => _onComboSearchChanged(),
                          ),
                          if (_comboSearchResults.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 120),
                              decoration: BoxDecoration(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.02),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _comboSearchResults.length,
                                itemBuilder: (context, idx) {
                                  final food = _comboSearchResults[idx];
                                  return ListTile(
                                    dense: true,
                                    title: Text(food.name,
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 12)),
                                    onTap: () => _addItemToNewCombo(food),
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: (_newComboItems.isNotEmpty &&
                                    _comboNameCtrl.text.trim().isNotEmpty)
                                ? _saveNewCombo
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text("Salvar Refeição 🍱",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Suas Refeições Salvas",
                                  style: TextStyle(
                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), fontSize: 12)),
                              TextButton.icon(
                                icon: const Icon(Icons.add,
                                    size: 14, color: Colors.amber),
                                label: const Text("Criar Novo",
                                    style: TextStyle(
                                        color: Colors.amber, fontSize: 11)),
                                onPressed: () =>
                                    setState(() => _isCreatingCombo = true),
                              ),
                            ],
                          ),
                          if (_loadingFavsOrPresets)
                            const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.amber))
                          else if (_presets.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  "Nenhuma refeição salva ainda.",
                                  style: TextStyle(
                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93)), fontSize: 12),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _presets.length,
                              separatorBuilder: (_, __) => Divider(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                                  height: 1),
                              itemBuilder: (context, index) {
                                final preset = _presets[index];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    preset.name,
                                    style: TextStyle(
                                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    "${preset.items.length} itens | ${preset.totalCalories} kcal",
                                    style: TextStyle(
                                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : const Color(0xFF48484A)), fontSize: 11),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.redAccent, size: 16),
                                    onPressed: () => _deletePreset(preset.id),
                                  ),
                                  onTap: () => _registerPresetMeal(preset),
                                );
                              },
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancelar",
                        style: TextStyle(
                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                            fontWeight: FontWeight.bold)),
                  ),
                  if (_activeTab == 0 &&
                      (_selectedFood != null ||
                          (_isManualMode &&
                              _manualNameCtrl.text.isNotEmpty))) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _registerMeal,
                      child: Text(
                        "Adicionar",
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ==========================================
// 2. ÁGUA TAB
// ==========================================
class AguaTab extends StatelessWidget {
  final Color accentColor;
  const AguaTab({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DietProvider>(context);
    final diet = provider.diet;

    final waterProgress = diet.waterGoalMl > 0
        ? (diet.waterIntakeMl / diet.waterGoalMl).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Copo/Medidor visual
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Container de fundo que imita o copo
                Container(
                  width: 140,
                  height: 200,
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.03),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20), top: Radius.circular(8)),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12), width: 3),
                  ),
                ),
                // Água preenchida proporcionalmente (WaveCupWidget animado)
                WaveCupWidget(progress: waterProgress),
                // Texto central
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${diet.waterIntakeMl} ml",
                          style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                              fontSize: 22,
                              fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Meta: ${diet.waterGoalMl} ml",
                          style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Botões Rápidos
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                _buildWaterAddBtn(provider, diet.waterIntakeMl, 150),
                _buildWaterAddBtn(provider, diet.waterIntakeMl, 250),
                _buildWaterAddBtn(provider, diet.waterIntakeMl, 350),
                _buildWaterAddBtn(provider, diet.waterIntakeMl, 500),
              ],
            ),
            const SizedBox(height: 24),

            // Resetar
            TextButton.icon(
              onPressed: () {
                provider.updateWaterIntake(0);
              },
              icon: Icon(Icons.refresh, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), size: 16),
              label: Text("Zerar Consumo",
                  style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterAddBtn(DietProvider provider, int current, int val) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          provider.updateWaterIntake(current + val);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.04),
          foregroundColor: Colors.blueAccent,
          padding: EdgeInsets.zero,
          elevation: 0,
          side: BorderSide(
              color: Colors.blueAccent.withOpacity(0.25), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.water_drop, color: Colors.blueAccent, size: 16),
            const SizedBox(width: 4),
            Text(
              "+$val ml",
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. JEJUM TAB
// ==========================================
class JejumTab extends StatefulWidget {
  final Color accentColor;
  const JejumTab({super.key, required this.accentColor});

  @override
  State<JejumTab> createState() => _JejumTabState();
}

class _JejumTabState extends State<JejumTab> {
  Timer? _timer;
  late final ValueNotifier<Duration> _elapsedNotifier;
  double _selectedGoalHours = 16.0;
  DateTime _selectedStartTime = DateTime.now();

  Future<void> _pickStartTime(StateSetter setDialogState) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedStartTime,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: widget.accentColor,
              onPrimary: Colors.black,
              surface: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedStartTime),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: widget.accentColor,
              onPrimary: Colors.black,
              surface: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    final newTime = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    if (newTime.isAfter(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O início não pode ser no futuro.')));
      return;
    }
    setDialogState(() {
      _selectedStartTime = newTime;
    });
  }

  @override
  void initState() {
    super.initState();
    _elapsedNotifier = ValueNotifier<Duration>(Duration.zero);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsedNotifier.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final provider = Provider.of<DietProvider>(context, listen: false);
      final active = provider.diet.fasting.active;
      if (active != null) {
        try {
          final start = DateTime.parse(active.startTime);
          final now = DateTime.now().toUtc();
          _elapsedNotifier.value = now.difference(start);
        } catch (e) {
          // parse error
        }
      }
      if (provider.diet.abstinence.isNotEmpty) {
        setState(() {});
      }
    });
  }

  Widget _buildFastingStats(DietProvider provider) {
    final history = provider.diet.fasting.history;
    final completedFasts = history.where((f) => f.endTime != null).length;
    final totalHours = history.fold<double>(0, (sum, f) {
      if (f.endTime != null) {
        try {
          final start = DateTime.parse(f.startTime);
          final end = DateTime.parse(f.endTime!);
          return sum + end.difference(start).inHours;
        } catch (e) {
          return sum;
        }
      }
      return sum;
    });
    final avgHours = completedFasts > 0 ? totalHours / completedFasts : 0.0;

    // Calculate unique days with fasting
    final uniqueDays = <String>{};
    for (final fast in history) {
      if (fast.endTime != null) {
        try {
          final date = DateTime.parse(fast.startTime);
          uniqueDays.add("${date.year}-${date.month}-${date.day}");
        } catch (e) {
          // parse error
        }
      }
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Estatísticas de Jejum",
            style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Jejuns Completados",
                  completedFasts.toString(),
                  Icons.check_circle,
                  (Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent : const Color(0xFF1E8E3E)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Média de Horas",
                  "${avgHours.toStringAsFixed(1)}h",
                  Icons.schedule,
                  Colors.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Total de Horas",
                  "${totalHours.toStringAsFixed(0)}h",
                  Icons.access_time,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Dias com Jejum",
                  uniqueDays.length.toString(),
                  Icons.calendar_today,
                  Colors.purpleAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : const Color(0xFF48484A)),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showEndFastingOptions(BuildContext context, DietProvider provider) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
        title: const Text(
          "Finalizar Jejum",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.amber),
              title: const Text(
                "Agora",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(dialogCtx);
                provider.endFasting();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Jejum finalizado com sucesso!"),
                    backgroundColor: Colors.amber,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.blueAccent),
              title: const Text(
                "Horário personalizado",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(dialogCtx);
                _showCustomEndTimeDialog(context, provider);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text("Cancelar", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : const Color(0xFF48484A)), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCustomEndTimeDialog(BuildContext context, DietProvider provider) {
    DateTime selectedTime = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
        title: const Text(
          "Horário de Término",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Selecione quando você terminou o jejum:",
              style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43))),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: DateTime.now(),
                minimumDate: DateTime.now().subtract(const Duration(days: 7)),
                maximumDate: DateTime.now(),
                onDateTimeChanged: (DateTime newTime) {
                  selectedTime = newTime;
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child:
                Text("Cancelar", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : const Color(0xFF48484A)))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              provider.endFastingWithCustomTime(selectedTime);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Jejum finalizado com horário personalizado!"),
                  backgroundColor: Colors.amber,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
            ),
            child:
                const Text("Confirmar", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showManualFastingDialog(BuildContext context, DietProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ManualFastingSheet(
        provider: provider,
        accentColor: widget.accentColor,
      ),
    );
  }

  Widget _buildMotivationalQuote(Duration elapsed) {
    final hours = elapsed.inSeconds / 3600;
    final quotes = [
      if (hours < 2) "O jejum começa com um passo. Continue firme! 💪",
      if (hours < 12) "Seu corpo está se adaptando. Cada minuto conta! ⏰",
      if (hours < 18) "Você está entrando na zona de queima de gordura! 🔥",
      if (hours < 24) "Incrível! Seu corpo está transformando energia! ✨",
      "Autofagia em andamento! Seu corpo está se renovando! 🌟",
    ];

    final quote = quotes.firstWhere((q) => q.isNotEmpty,
        orElse: () => "Continue firme! Você está no caminho certo! 💪");

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.format_quote,
              color: widget.accentColor.withOpacity(0.6), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              quote,
              style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)),
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastingStageCard(Duration elapsed) {
    final hours = elapsed.inSeconds / 3600;
    String stageTitle = "";
    String stageDesc = "";
    Color stageColor = Colors.amber;
    IconData stageIcon = Icons.access_time;

    if (hours < 2) {
      stageTitle = "Absorção de Nutrientes";
      stageDesc =
          "Seu corpo está digerindo a última refeição. Nível de açúcar sobe.";
      stageColor = Colors.blueAccent;
      stageIcon = Icons.restaurant;
    } else if (hours < 12) {
      stageTitle = "Queda de Insulina";
      stageDesc =
          "A glicose diminui e o pâncreas reduz a liberação de insulina.";
      stageColor = Colors.cyan;
      stageIcon = Icons.trending_down;
    } else if (hours < 18) {
      stageTitle = "Início de Cetose";
      stageDesc =
          "O glicogênio hepático se esgota. O corpo começa a queimar gordura.";
      stageColor = Colors.orangeAccent;
      stageIcon = Icons.local_fire_department;
    } else if (hours < 24) {
      stageTitle = "Queima de Gordura Ativa";
      stageDesc =
          "A queima de gordura acelera. O hormônio do crescimento (GH) sobe.";
      stageColor = Colors.amber;
      stageIcon = Icons.whatshot;
    } else {
      stageTitle = "Autofagia";
      stageDesc =
          "O corpo inicia a reciclagem de células velhas ou danificadas.";
      stageColor = (Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent : const Color(0xFF1E8E3E));
      stageIcon = Icons.autorenew;
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: stageColor.withOpacity(0.3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: stageColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(stageIcon, color: stageColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stageTitle,
                    style: TextStyle(
                        color: stageColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stageDesc,
                    style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularProtocols(Function(double) onSelected) {
    final protocols = [
      {"name": "12h Leve", "hours": 12.0, "icon": Icons.wb_sunny},
      {"name": "14h Moderado", "hours": 14.0, "icon": Icons.wb_twilight},
      {"name": "16h Padrão", "hours": 16.0, "icon": Icons.nights_stay},
      {"name": "18h Avançado", "hours": 18.0, "icon": Icons.flash_on},
      {"name": "24h Completo", "hours": 24.0, "icon": Icons.all_inclusive},
      {"name": "OMAD (23h)", "hours": 23.0, "icon": Icons.restaurant_menu},
    ];

    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: protocols.length,
        itemBuilder: (context, idx) {
          final p = protocols[idx];
          final name = p["name"] as String;
          final h = p["hours"] as double;
          final icon = p["icon"] as IconData;
          final isSel = _selectedGoalHours == h;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(h),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel
                      ? widget.accentColor.withOpacity(0.2)
                      : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel
                        ? widget.accentColor.withOpacity(0.4)
                        : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSel ? widget.accentColor : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : const Color(0xFF48484A)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: TextStyle(
                        color: isSel ? widget.accentColor : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DietProvider>(context);
    final diet = provider.diet;

    final active = diet.fasting.active;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
        child: Column(
          children: [
            if (active != null) ...[
              // JEJUM ATIVO
              GlassCard(
                padding: const EdgeInsets.all(20),
                borderColor: Colors.amber.withOpacity(0.25),
                child: Column(
                  children: [
                    const Text(
                      "Jejum em Andamento 🔥",
                      style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 20),

                    // Relógio e Barra de Progresso reativos com design premium
                    ValueListenableBuilder<Duration>(
                      valueListenable: _elapsedNotifier,
                      builder: (context, elapsed, child) {
                        final isIndefinite = active.goalDurationHours == 0.0;
                        final goalSecs = active.goalDurationHours * 3600;
                        final elapsedSecs = elapsed.inSeconds;
                        final progress = goalSecs > 0
                            ? (elapsedSecs / goalSecs).clamp(0.0, 1.0)
                            : 0.0;
                        final remainingSecs = goalSecs > 0
                            ? (goalSecs - elapsedSecs)
                                .clamp(0, goalSecs.toInt())
                            : 0;

                        return Column(
                          children: [
                            // Circular Progress Indicator Premium
                            SizedBox(
                              height: 200,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Background circle
                                  SizedBox(
                                    height: 180,
                                    width: 180,
                                    child: CircularProgressIndicator(
                                      value: 1.0,
                                      strokeWidth: 12,
                                      backgroundColor:
                                          (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05)),
                                    ),
                                  ),
                                  // Progress circle
                                  if (!isIndefinite)
                                    SizedBox(
                                      height: 180,
                                      width: 180,
                                      child: CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 12,
                                        backgroundColor: Colors.transparent,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                Colors.amber),
                                      ),
                                    ),
                                  // Center content
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _formatDuration(elapsed),
                                        style: TextStyle(
                                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (!isIndefinite)
                                        Text(
                                          "Restante: ${_formatDuration(Duration(seconds: remainingSecs.toInt()))}",
                                          style: TextStyle(
                                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color:
                                                  Colors.amber.withOpacity(0.3),
                                              width: 1),
                                        ),
                                        child: Text(
                                          isIndefinite
                                              ? "Indefinido"
                                              : "${(progress * 100).toStringAsFixed(0)}%",
                                          style: const TextStyle(
                                              color: Colors.amber,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isIndefinite
                                  ? "Jejum por Tempo Indefinido"
                                  : "Meta: ${active.goalDurationHours.toStringAsFixed(0)} horas",
                              style: TextStyle(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            _buildFastingStageCard(elapsed),
                            const SizedBox(height: 16),
                            _buildMotivationalQuote(elapsed),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Botões de Ação
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: () {
                                _showEndFastingOptions(context, provider);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Finalizar Jejum",
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // CONFIGURAR JEJUM
              Column(
                children: [
                  // Fasting Statistics Card
                  _buildFastingStats(provider),
                  const SizedBox(height: 16),
                  // Manual Fasting Entry Button
                  TextButton.icon(
                    onPressed: () =>
                        _showManualFastingDialog(context, provider),
                    icon: Icon(Icons.history,
                        color: widget.accentColor, size: 16),
                    label: Text("Adicionar jejum manual",
                        style: TextStyle(
                            color: widget.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero, minimumSize: Size.zero),
                  ),
                  const SizedBox(height: 16),
                  // Start Fasting Card
                  StatefulBuilder(
                    builder: (context, setDialogState) {
                      return GlassCard(
                        padding: const EdgeInsets.all(20),
                        borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.04),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                "Iniciar Novo Jejum",
                                style: TextStyle(
                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Text(
                              "Protocolos Sugeridos",
                              style: TextStyle(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            _buildPopularProtocols((h) {
                              setDialogState(() {
                                _selectedGoalHours = h;
                              });
                            }),

                            Text(
                              "Duração Meta",
                              style: TextStyle(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<double>(
                                  value: _selectedGoalHours,
                                  dropdownColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
                                  style: TextStyle(
                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                  isExpanded: true,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        _selectedGoalHours = val;
                                      });
                                    }
                                  },
                                  items: [
                                    12.0,
                                    14.0,
                                    16.0,
                                    18.0,
                                    20.0,
                                    23.0,
                                    24.0,
                                    36.0,
                                    48.0
                                  ]
                                      .map((h) => DropdownMenuItem(
                                          value: h, child: Text("$h horas")))
                                      .toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Text(
                              "Horário de Início",
                              style: TextStyle(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _pickStartTime(setDialogState),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "${_selectedStartTime.day.toString().padLeft(2, '0')}/${_selectedStartTime.month.toString().padLeft(2, '0')} às ${_selectedStartTime.hour.toString().padLeft(2, '0')}:${_selectedStartTime.minute.toString().padLeft(2, '0')}",
                                      style: TextStyle(
                                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Icon(Icons.edit_calendar, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Botões de Ação
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        provider.startFasting(0.0, startTime: _selectedStartTime);
                                        _elapsedNotifier.value = DateTime.now().difference(_selectedStartTime);
                                        _startTimer();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.06),
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                            color:
                                                Colors.white.withOpacity(0.15),
                                            width: 1.2),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        "Jejum Indefinido",
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        provider.startFasting(_selectedGoalHours, startTime: _selectedStartTime);
                                        _elapsedNotifier.value = DateTime.now().difference(_selectedStartTime);
                                        _startTimer();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: widget.accentColor,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        "Iniciar Meta",
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // SEÇÃO DE ABSTINÊNCIAS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Abstinências Ativas",
                  style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
                TextButton.icon(
                  onPressed: () => _showAddAbstinenceDialog(context, provider),
                  icon: Icon(Icons.add_circle_outline,
                      color: widget.accentColor, size: 16),
                  label: Text("Nova",
                      style: TextStyle(
                          color: widget.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, minimumSize: Size.zero),
                ),
              ],
            ),
            const SizedBox(height: 10),

            diet.abstinence.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        "Nenhuma abstinência registrada.",
                        style: TextStyle(
                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFC7C7CC)),
                            fontStyle: FontStyle.italic,
                            fontSize: 12),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: diet.abstinence.length,
                    itemBuilder: (context, index) {
                      final a = diet.abstinence[index];

                      Duration elapsed = Duration.zero;
                      try {
                        final start = DateTime.parse(a.startTime);
                        final now = DateTime.now().toUtc();
                        elapsed = now.difference(start);
                      } catch (e) {
                        // ignore
                      }

                      final days = elapsed.inDays;
                      final hours = elapsed.inHours.remainder(24);
                      final minutes = elapsed.inMinutes.remainder(60);
                      final seconds = elapsed.inSeconds.remainder(60);

                      String timeStr = "";
                      if (days > 0) {
                        timeStr += "$days ${days == 1 ? 'dia' : 'dias'}, ";
                      }
                      timeStr += "${hours}h ${minutes}m ${seconds}s";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.04),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.title,
                                      style: TextStyle(
                                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Tempo: $timeStr",
                                      style: TextStyle(
                                          color: widget.accentColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    if (a.notes != null &&
                                        a.notes!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        a.notes!,
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93)),
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.refresh,
                                        color: Colors.amber, size: 18),
                                    tooltip: "Reiniciar contador",
                                    onPressed: () => _confirmResetAbstinence(
                                        context, provider, a),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.redAccent, size: 18),
                                    tooltip: "Excluir rastreador",
                                    onPressed: () =>
                                        provider.deleteAbstinence(a.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),

            // HISTÓRICO DE JEJUNS
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Histórico de Jejuns",
                style: TextStyle(
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),

            diet.fasting.history.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        "Nenhum jejum concluído no histórico.",
                        style: TextStyle(
                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93)), fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: diet.fasting.history.length,
                    itemBuilder: (context, index) {
                      final f = diet.fasting.history[index];

                      Duration diff = Duration.zero;
                      try {
                        final start = DateTime.parse(f.startTime);
                        final end = DateTime.parse(f.endTime ?? '');
                        diff = end.difference(start);
                      } catch (e) {
                        // ignore
                      }

                      final goalHours = f.goalDurationHours;
                      final reached = diff.inSeconds >= (goalHours * 3600);
                      final startLocal =
                          DateTime.tryParse(f.startTime)?.toLocal();
                      final dateStr = startLocal != null
                          ? "${startLocal.day.toString().padLeft(2, '0')}/${startLocal.month.toString().padLeft(2, '0')}"
                          : "";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          borderColor: reached
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        reached
                                            ? "Meta Cumprida 🎉"
                                            : "Jejum Incompleto ⚠️",
                                        style: TextStyle(
                                          color: reached
                                              ? Colors.green
                                              : Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Data: $dateStr",
                                        style: TextStyle(
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93)),
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Fasting de ${goalHours.toStringAsFixed(0)}h",
                                    style: TextStyle(
                                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), fontSize: 11),
                                  ),
                                ],
                              ),
                              Text(
                                _formatDurationShort(diff),
                                style: TextStyle(
                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  void _showAddAbstinenceDialog(BuildContext context, DietProvider provider) {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    DateTime selectedDateTime = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          Future<void> pickDateTime() async {
            final date = await showDatePicker(
              context: dialogCtx,
              initialDate: selectedDateTime,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: widget.accentColor,
                    onPrimary: Colors.black,
                    surface: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
                  ),
                ),
                child: child!,
              ),
            );
            if (date == null) return;

            if (!dialogCtx.mounted) return;
            final time = await showTimePicker(
              context: dialogCtx,
              initialTime: TimeOfDay.fromDateTime(selectedDateTime),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: widget.accentColor,
                    onPrimary: Colors.black,
                    surface: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
                  ),
                ),
                child: child!,
              ),
            );
            if (time == null) return;

            setDialogState(() {
              selectedDateTime = DateTime(
                  date.year, date.month, date.day, time.hour, time.minute);
            });
          }

          final displayStr =
              "${selectedDateTime.day.toString().padLeft(2, '0')}/${selectedDateTime.month.toString().padLeft(2, '0')} às ${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}";

          return Dialog(
            backgroundColor: Colors.transparent,
            child: GlassCard(
              useBlur: true,
              borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
              borderRadius: 20,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Nova Abstinência",
                    style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                      hintText: "O que você vai parar? (ex: Açúcar)",
                      hintStyle:
                          TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white30 : const Color(0xFFAEAEB2)), fontSize: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                      hintText: "Notas / Motivação (Opcional)",
                      hintStyle:
                          TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white30 : const Color(0xFFAEAEB2)), fontSize: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date and Time picker trigger
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Iniciado em:",
                            style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Caso já tenha começado",
                            style:
                                TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFC7C7CC)), fontSize: 10),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: pickDateTime,
                        icon: Icon(Icons.calendar_today,
                            color: widget.accentColor, size: 14),
                        label: Text(
                          displayStr,
                          style: TextStyle(
                              color: widget.accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.04),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text("Cancelar",
                            style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          final title = titleCtrl.text.trim();
                          if (title.isNotEmpty) {
                            provider.addAbstinence(
                              title,
                              notesCtrl.text.trim(),
                              selectedDateTime.toUtc().toIso8601String(),
                            );
                            Navigator.pop(dialogCtx);
                          }
                        },
                        child: Text("Iniciar",
                            style: TextStyle(
                                color: widget.accentColor,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmResetAbstinence(
      BuildContext context, DietProvider provider, AbstinenceRecord a) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          useBlur: true,
          borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
          borderRadius: 20,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Zerar Contador?",
                style: TextStyle(
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                "Deseja realmente reiniciar o tempo de '${a.title}'? O contador recomeçará do zero.",
                style: TextStyle(
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text("Cancelar",
                        style: TextStyle(
                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      provider.resetAbstinence(a.id);
                      Navigator.pop(dialogCtx);
                    },
                    child: const Text("Zerar",
                        style: TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatDurationShort(Duration d) {
    if (d.inHours > 0) {
      return "${d.inHours}h ${d.inMinutes.remainder(60)}m";
    }
    return "${d.inMinutes}m";
  }
}

// ==========================================
// WAVE CUP WIDGET & PAINTER
// ==========================================
class WaveCupWidget extends StatefulWidget {
  final double progress;
  const WaveCupWidget({super.key, required this.progress});

  @override
  State<WaveCupWidget> createState() => _WaveCupWidgetState();
}

class _WaveCupWidgetState extends State<WaveCupWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(134, 194),
          painter: WavePainter(
            progress: widget.progress,
            waveValue: _controller.value,
          ),
        );
      },
    );
  }
}

class WavePainter extends CustomPainter {
  final double progress;
  final double waveValue;

  WavePainter({required this.progress, required this.waveValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xff0a84ff).withOpacity(0.75),
          const Color(0xff30a2ff).withOpacity(0.50),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();

    // Altura base da água baseada no progresso
    final baseHeight = size.height * (1.0 - progress);

    // Desenhar a onda senoidal superior da água
    path.moveTo(0, size.height);
    path.lineTo(0, baseHeight);

    // Frequência e amplitude da onda
    const waveFrequency = 1.8 * 3.14159;
    final waveAmplitude = progress > 0.0 && progress < 1.0 ? 4.5 : 0.0;

    for (double x = 0; x <= size.width; x++) {
      final y = baseHeight +
          waveAmplitude *
              math.sin(
                  (x / size.width) * waveFrequency + (waveValue * 2 * math.pi));
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    // Recortar no formato arredondado inferior do copo
    final clipPath = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, size.width, size.height),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
          topLeft: Radius.circular(progress >= 0.98 ? 8 : 4),
          topRight: Radius.circular(progress >= 0.98 ? 8 : 4),
        ),
      );

    canvas.save();
    canvas.clipPath(clipPath);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveValue != waveValue;
  }
}

class _ManualFastingSheet extends StatefulWidget {
  final DietProvider provider;
  final Color accentColor;
  const _ManualFastingSheet(
      {required this.provider, required this.accentColor});

  @override
  State<_ManualFastingSheet> createState() => _ManualFastingSheetState();
}

class _ManualFastingSheetState extends State<_ManualFastingSheet> {
  late DateTime _startTime;
  late DateTime _endTime;

  bool _showStartPicker = false;
  bool _showEndPicker = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now().subtract(const Duration(hours: 16));
    _endTime = DateTime.now();
  }

  String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: const Color(0xff0d0d0f).withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border:
                Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08), width: 1.5),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Adicionar Jejum Manual",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), size: 22),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Início e Término
              _buildDateTile(
                title: "Início do Jejum",
                date: _startTime,
                isExpanded: _showStartPicker,
                onTap: () => setState(() {
                  _showStartPicker = !_showStartPicker;
                  _showEndPicker = false;
                }),
                onChanged: (val) => setState(() => _startTime = val),
              ),
              const SizedBox(height: 12),
              _buildDateTile(
                title: "Término do Jejum",
                date: _endTime,
                isExpanded: _showEndPicker,
                onTap: () => setState(() {
                  _showEndPicker = !_showEndPicker;
                  _showStartPicker = false;
                }),
                onChanged: (val) => setState(() => _endTime = val),
                minimumDate: _startTime,
              ),

              const SizedBox(height: 32),

              // Botão Salvar
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveFast,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    "SALVAR JEJUM",
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTile({
    required String title,
    required DateTime date,
    required bool isExpanded,
    required VoidCallback onTap,
    required ValueChanged<DateTime> onChanged,
    DateTime? minimumDate,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isExpanded
                      ? widget.accentColor.withOpacity(0.5)
                      : Colors.transparent),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)),
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    color: isExpanded ? widget.accentColor : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 12),
          Container(
            height: 160,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.accentColor.withOpacity(0.25)),
            ),
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Brightness.dark,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                use24hFormat: true,
                initialDateTime: date,
                minimumDate: minimumDate,
                maximumDate: DateTime.now(),
                onDateTimeChanged: onChanged,
              ),
            ),
          ),
        ]
      ],
    );
  }

  void _saveFast() {
    if (_endTime.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("O término deve ser após o início"),
            backgroundColor: Colors.red),
      );
      return;
    }
    final durationHours = _endTime.difference(_startTime).inMinutes / 60.0;
    widget.provider.addManualFastingRecord(_startTime, _endTime, durationHours);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: const Text("Jejum manual adicionado!"),
          backgroundColor: widget.accentColor),
    );
  }
}
