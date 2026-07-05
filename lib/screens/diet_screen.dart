import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/tracker_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';
import '../models/diet.dart';
import '../models/food_item.dart';
import '../models/favorite_food.dart';
import '../models/meal_preset.dart';
import '../services/food_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.select<TrackerProvider, Color>(
      (p) => ThemeUtils.getColor(p.currentProfile.colorAccent),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: "Refeições"),
            Tab(text: "Água"),
            Tab(text: "Jejum"),
            Tab(text: "Gráficos"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefeicoesTab(accentColor: accentColor),
          AguaTab(accentColor: accentColor),
          JejumTab(accentColor: accentColor),
          HistoricoTab(accentColor: accentColor),
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
    final provider = Provider.of<TrackerProvider>(context);
    final diet = provider.state?.diet;

    if (diet == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    // Cálculos
    int totalCals = diet.meals.fold<int>(0, (sum, m) => sum + m.calories);
    int activeCals = provider.todayBurnedCalories;
    int netCals = totalCals - activeCals;
    if (netCals < 0) netCals = 0;

    double totalProt = diet.meals.fold<double>(0, (sum, m) => sum + m.protein);
    double totalCarbs = diet.meals.fold<double>(0, (sum, m) => sum + m.carbs);
    double totalFat = diet.meals.fold<double>(0, (sum, m) => sum + m.fat);

    final netProgress = diet.caloriesGoal > 0 ? (netCals / diet.caloriesGoal).clamp(0.0, 1.0) : 0.0;
    final protProgress = diet.proteinGoal > 0 ? (totalProt / diet.proteinGoal).clamp(0.0, 1.0) : 0.0;
    final carbsProgress = diet.carbsGoal > 0 ? (totalCarbs / diet.carbsGoal).clamp(0.0, 1.0) : 0.0;
    final fatProgress = diet.fatGoal > 0 ? (totalFat / diet.fatGoal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          onPressed: () {
            _openAddMealDialog(context, provider);
          },
          backgroundColor: accentColor,
          mini: true,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumo de Calorias & Macros
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: Colors.white.withOpacity(0.04),
              child: Column(
                children: [
                  // Linha Calorias
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Saldo Líquido de Calorias", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            "$netCals / ${diet.caloriesGoal} kcal",
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Consumido: $totalCals kcal • Ativo: $activeCals kcal",
                            style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text(
                        "${(netProgress * 100).toStringAsFixed(0)}%",
                        style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: netProgress,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 16),

                  // Linhas Macros (Proteína, Carbo, Gordura)
                  Row(
                    children: [
                      Expanded(child: _buildMacroBar("Proteínas", totalProt, diet.proteinGoal, protProgress, const Color(0xffff453a))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMacroBar("Carboidratos", totalCarbs, diet.carbsGoal, carbsProgress, const Color(0xffbf5af2))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMacroBar("Gorduras", totalFat, diet.fatGoal, fatProgress, const Color(0xffff9f0a))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // HealthKit Summary / Opt-in Card
            if (provider.healthAuthorized) ...[
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                borderColor: Colors.white.withOpacity(0.04),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Active energy burned
                    Row(
                      children: [
                        const Text("🔥", style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Gasto Ativo", style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              "${provider.todayBurnedCalories} kcal",
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    // Steps
                    Row(
                      children: [
                        const Text("🚶", style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Passos", style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              "${provider.todaySteps}",
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Heart rate
                    Row(
                      children: [
                        const Text("❤️", style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Frequência", style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              provider.currentHeartRate > 0 ? "${provider.currentHeartRate} bpm" : "--",
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  borderColor: accentColor.withOpacity(0.3),
                  child: Row(
                    children: [
                      Icon(Icons.favorite, color: accentColor, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Conectar com App Saúde",
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Acompanhe calorias ativas, passos e batimentos cardíacos.",
                              style: TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Lista de Refeições
            const Text(
              "Refeições do Dia",
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),

            diet.meals.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        "Nenhuma refeição registrada hoje.",
                        style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: diet.meals.length,
                    itemBuilder: (context, index) {
                      final meal = diet.meals[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          borderColor: Colors.white.withOpacity(0.04),
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
                                        Text(
                                          meal.name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          meal.time,
                                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _buildMiniMacroLabel("P", meal.protein, const Color(0xffff453a)),
                                        const SizedBox(width: 8),
                                        _buildMiniMacroLabel("C", meal.carbs, const Color(0xffbf5af2)),
                                        const SizedBox(width: 8),
                                        _buildMiniMacroLabel("G", meal.fat, const Color(0xffff9f0a)),
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
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      provider.deleteMeal(meal.id);
                                    },
                                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                  ),
                                ],
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

  Widget _buildMacroBar(String name, double val, double goal, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(
          "${val.toStringAsFixed(1)}/${goal.toStringAsFixed(0)}g",
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white.withOpacity(0.05),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(2),
          minHeight: 4,
        ),
      ],
    );
  }

  Widget _buildMiniMacroLabel(String letter, double val, Color color) {
    return Row(
      children: [
        Text(
          letter,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 2),
        Text(
          "${val.toStringAsFixed(1)}g",
          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _openAddMealDialog(BuildContext context, TrackerProvider provider) {
    final accentColor = ThemeUtils.getColor(provider.currentProfile.colorAccent);
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
  final TrackerProvider provider;
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

  // Abas do dialog: 0 = Busca/IA, 1 = Favoritos, 2 = Combos
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
  String? _errorMessage;

  FoodItem? _selectedFood;
  bool _isManualMode = false;

  @override
  void initState() {
    super.initState();
    _loadFavoritesAndPresets();
  }

  void _loadFavoritesAndPresets() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    setState(() => _loadingFavsOrPresets = true);
    try {
      final favs = await _foodService.getFavorites(userId);
      final prets = await _foodService.getPresets(userId);
      setState(() {
        _favorites = favs;
        _presets = prets;
        _loadingFavsOrPresets = false;
      });
    } catch (e) {
      setState(() => _loadingFavsOrPresets = false);
    }
  }

  void _onSearchChanged() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedFood = null;
      _isManualMode = false;
    });

    try {
      final results = await _foodService.searchFoods(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erro ao buscar alimentos.";
        _isLoading = false;
      });
    }
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
    final qty = double.tryParse(_quantityCtrl.text.trim()) ?? _selectedFood!.servingSize.toDouble();
    
    // Se for um alimento retornado pela IA sem ID no banco global, cadastramos globalmente antes de favoritar
    if (_selectedFood!.id.isEmpty) {
      await _foodService.addFood(_selectedFood!);
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
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final scale = fav.favoriteQuantity / fav.food.servingSize;

    final name = fav.food.name;
    final calories = (fav.food.calories * scale).round();
    final protein = double.parse((fav.food.protein * scale).toStringAsFixed(1));
    final carbs = double.parse((fav.food.carbs * scale).toStringAsFixed(1));
    final fat = double.parse((fav.food.fat * scale).toStringAsFixed(1));

    widget.provider.addMeal(name, calories, protein, carbs, fat, timeStr);
    Navigator.pop(context);
  }

  // --- MÉTODOS DE COMBO/PRESETS ---

  void _onComboSearchChanged() async {
    final query = _comboSearchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() => _comboSearchResults = []);
      return;
    }
    try {
      final results = await _foodService.searchFoods(query);
      setState(() => _comboSearchResults = results);
    } catch (e) {
      debugPrint("Erro ao buscar alimento para o combo: $e");
    }
  }

  void _addItemToNewCombo(FoodItem food) {
    setState(() {
      _newComboItems.add(MealPresetItem(food: food, quantity: food.servingSize.toDouble()));
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
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    for (final item in preset.items) {
      final scale = item.quantity / item.food.servingSize;
      final name = item.food.name;
      final calories = (item.food.calories * scale).round();
      final protein = double.parse((item.food.protein * scale).toStringAsFixed(1));
      final carbs = double.parse((item.food.carbs * scale).toStringAsFixed(1));
      final fat = double.parse((item.food.fat * scale).toStringAsFixed(1));

      widget.provider.addMeal(name, calories, protein, carbs, fat, timeStr);
    }
    Navigator.pop(context);
  }

  void _registerMeal() async {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    if (_isManualMode) {
      final name = _manualNameCtrl.text.trim();
      if (name.isEmpty) return;

      final calories = int.tryParse(_manualCalsCtrl.text.trim()) ?? 0;
      final protein = double.tryParse(_manualProtCtrl.text.trim()) ?? 0.0;
      final carbs = double.tryParse(_manualCarbsCtrl.text.trim()) ?? 0.0;
      final fat = double.tryParse(_manualFatCtrl.text.trim()) ?? 0.0;

      widget.provider.addMeal(name, calories, protein, carbs, fat, timeStr);
      Navigator.pop(context);
    } else if (_selectedFood != null) {
      // Se for um alimento novo vindo da IA (ID vazio), salvamos no Firestore global
      if (_selectedFood!.id.isEmpty) {
        await _foodService.addFood(_selectedFood!);
      }

      final quantity = double.tryParse(_quantityCtrl.text.trim()) ?? _selectedFood!.servingSize.toDouble();
      final scale = quantity / _selectedFood!.servingSize;

      final name = _selectedFood!.name;
      final calories = (_selectedFood!.calories * scale).round();
      final protein = double.parse((_selectedFood!.protein * scale).toStringAsFixed(1));
      final carbs = double.parse((_selectedFood!.carbs * scale).toStringAsFixed(1));
      final fat = double.parse((_selectedFood!.fat * scale).toStringAsFixed(1));

      widget.provider.addMeal(name, calories, protein, carbs, fat, timeStr);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }



  @override
  void dispose() {
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
      fillColor: Colors.white.withOpacity(0.05),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          _tabHeaderItem(0, "Busca", Icons.search),
          _tabHeaderItem(1, "Favoritos", Icons.star),
          _tabHeaderItem(2, "Combos", Icons.brunch_dining),
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
              Icon(icon, size: 16, color: active ? accentColor : Colors.white38),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
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
        borderColor: Colors.white.withOpacity(0.08),
        borderRadius: 20,
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Registrar Refeição",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 16),
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
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: _dialogInputDeco("Buscar alimento (ex: Banana, Ovo)..."),
                          onChanged: (_) => _onSearchChanged(),
                        ),
                        const SizedBox(height: 10),

                        if (_errorMessage != null) ...[
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                        ],

                        if (_isLoading) ...[
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                        ],

                        if (!_isLoading && _searchResults.isNotEmpty) ...[
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const ClampingScrollPhysics(),
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                              itemBuilder: (context, index) {
                                final item = _searchResults[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Text(
                                    "${item.calories} kcal | P: ${item.protein}g | C: ${item.carbs}g | G: ${item.fat}g por ${item.servingSize.round()}g",
                                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                                  ),
                                  onTap: () => _selectFood(item),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                          InkWell(
                            onTap: _switchToManual,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit_note_rounded, color: accentColor, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Criar Alimento Manual",
                                    style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                        if (_selectedFood != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedFood!.name,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.star_border, color: Colors.amber, size: 18),
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
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        decoration: _dialogInputDeco("Quantidade (g ou ml)"),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Informações Nutricionais Proporcionais
                                Builder(
                                  builder: (context) {
                                    final qty = double.tryParse(_quantityCtrl.text.trim()) ?? _selectedFood!.servingSize.toDouble();
                                    final scale = qty / _selectedFood!.servingSize;
                                    final calories = (_selectedFood!.calories * scale).round();
                                    final protein = _selectedFood!.protein * scale;
                                    final carbs = _selectedFood!.carbs * scale;
                                    final fat = _selectedFood!.fat * scale;

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Total: $calories kcal",
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            _macroBadge("P", "${protein.toStringAsFixed(1)}g", const Color(0xffff453a)),
                                            _macroBadge("C", "${carbs.toStringAsFixed(1)}g", const Color(0xffbf5af2)),
                                            _macroBadge("G", "${fat.toStringAsFixed(1)}g", const Color(0xffff9f0a)),
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
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Modo Manual ✍️",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _manualNameCtrl,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: _dialogInputDeco("Nome do alimento..."),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _manualCalsCtrl,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                        decoration: _dialogInputDeco("Calorias (kcal)"),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _manualProtCtrl,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                        decoration: _dialogInputDeco("Prot (g)"),
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
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                        decoration: _dialogInputDeco("Carbs (g)"),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _manualFatCtrl,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                        decoration: _dialogInputDeco("Gord (g)"),
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
                          const Center(child: CircularProgressIndicator(color: Colors.amber))
                        else if (_favorites.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                "Nenhum favorito salvo ainda.",
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _favorites.length,
                            separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                            itemBuilder: (context, index) {
                              final fav = _favorites[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(fav.food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(
                                  "${fav.favoriteQuantity.round()}g | ${(fav.food.calories * (fav.favoriteQuantity / fav.food.servingSize)).round()} kcal",
                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.star, color: Colors.amber, size: 16),
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
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: _dialogInputDeco("Nome do combo (ex: Café da Manhã)"),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.redAccent),
                                onPressed: () => setState(() => _isCreatingCombo = false),
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "${item.food.name} (${item.quantity.round()}g) - ${(item.food.calories * (item.quantity / item.food.servingSize)).round()} kcal",
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 16),
                                      onPressed: () => _removeItemFromNewCombo(idx),
                                    ),
                                  ],
                                );
                              },
                            ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _comboSearchCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: _dialogInputDeco("Buscar e adicionar alimento..."),
                            onChanged: (_) => _onComboSearchChanged(),
                          ),
                          if (_comboSearchResults.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 120),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _comboSearchResults.length,
                                itemBuilder: (context, idx) {
                                  final food = _comboSearchResults[idx];
                                  return ListTile(
                                    dense: true,
                                    title: Text(food.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                    onTap: () => _addItemToNewCombo(food),
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: (_newComboItems.isNotEmpty && _comboNameCtrl.text.trim().isNotEmpty) ? _saveNewCombo : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text("Salvar Combo 🥤", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Seus Combos", style: TextStyle(color: Colors.white70, fontSize: 12)),
                              TextButton.icon(
                                icon: const Icon(Icons.add, size: 14, color: Colors.amber),
                                label: const Text("Criar Novo", style: TextStyle(color: Colors.amber, fontSize: 11)),
                                onPressed: () => setState(() => _isCreatingCombo = true),
                              ),
                            ],
                          ),
                          if (_loadingFavsOrPresets)
                            const Center(child: CircularProgressIndicator(color: Colors.amber))
                          else if (_presets.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  "Nenhum combo salvo ainda.",
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _presets.length,
                              separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                              itemBuilder: (context, index) {
                                final preset = _presets[index];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    preset.name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    "${preset.items.length} itens | ${preset.totalCalories} kcal",
                                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
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
                    child: const Text("Cancelar", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                  if (_activeTab == 0 && (_selectedFood != null || (_isManualMode && _manualNameCtrl.text.isNotEmpty))) ...[
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
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _previewValue(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
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
    final provider = Provider.of<TrackerProvider>(context);
    final diet = provider.state?.diet;

    if (diet == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final waterProgress = diet.waterGoalMl > 0 ? (diet.waterIntakeMl / diet.waterGoalMl).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100),
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
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20), top: Radius.circular(8)),
                    border: Border.all(color: Colors.white.withOpacity(0.12), width: 3),
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
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Meta: ${diet.waterGoalMl} ml",
                          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700),
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
              icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
              label: const Text("Zerar Consumo", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterAddBtn(TrackerProvider provider, int current, int val) {
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
          side: BorderSide(color: Colors.blueAccent.withOpacity(0.25), width: 1.2),
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
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
      final provider = Provider.of<TrackerProvider>(context, listen: false);
      final active = provider.state?.diet.fasting.active;
      if (active != null) {
        try {
          final start = DateTime.parse(active.startTime);
          final now = DateTime.now().toUtc();
          _elapsedNotifier.value = now.difference(start);
        } catch (e) {
          // parse error
        }
      }
      if (provider.state?.diet.abstinence.isNotEmpty ?? false) {
        setState(() {});
      }
    });
  }

  Widget _buildFastingStageCard(Duration elapsed) {
    final hours = elapsed.inSeconds / 3600;
    String stageTitle = "";
    String stageDesc = "";
    Color stageColor = Colors.amber;

    if (hours < 2) {
      stageTitle = "Absorção de Nutrientes";
      stageDesc = "Seu corpo está digerindo a última refeição. Nível de açúcar sobe.";
      stageColor = Colors.blueAccent;
    } else if (hours < 12) {
      stageTitle = "Queda de Insulina";
      stageDesc = "A glicose diminui e o pâncreas reduz a liberação de insulina.";
      stageColor = Colors.cyan;
    } else if (hours < 18) {
      stageTitle = "Início de Cetose";
      stageDesc = "O glicogênio hepático se esgota. O corpo começa a queimar gordura.";
      stageColor = Colors.orangeAccent;
    } else if (hours < 24) {
      stageTitle = "Queima de Gordura Ativa";
      stageDesc = "A queima de gordura acelera. O hormônio do crescimento (GH) sobe.";
      stageColor = Colors.amber;
    } else {
      stageTitle = "Autofagia";
      stageDesc = "O corpo inicia a reciclagem de células velhas ou danificadas.";
      stageColor = Colors.greenAccent;
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderColor: stageColor.withOpacity(0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: stageColor),
                ),
                const SizedBox(width: 8),
                Text(
                  "Fase: $stageTitle",
                  style: TextStyle(color: stageColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              stageDesc,
              style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularProtocols(Function(double) onSelected) {
    final protocols = [
      {"name": "12h Leve", "hours": 12.0},
      {"name": "14h Moderado", "hours": 14.0},
      {"name": "16h Padrão", "hours": 16.0},
      {"name": "18h Avançado", "hours": 18.0},
      {"name": "24h Completo", "hours": 24.0},
      {"name": "OMAD (23h)", "hours": 23.0},
    ];

    return Container(
      height: 32,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: protocols.length,
        itemBuilder: (context, idx) {
          final p = protocols[idx];
          final name = p["name"] as String;
          final h = p["hours"] as double;
          final isSel = _selectedGoalHours == h;

          return Container(
            margin: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(name),
              selected: isSel,
              selectedColor: widget.accentColor.withOpacity(0.2),
              disabledColor: Colors.transparent,
              backgroundColor: Colors.white.withOpacity(0.04),
              labelStyle: TextStyle(
                color: isSel ? widget.accentColor : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onSelected: (selected) {
                if (selected) {
                  onSelected(h);
                }
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final diet = provider.state?.diet;

    if (diet == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final active = diet.fasting.active;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
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
                      style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 20),

                    // Relógio e Barra de Progresso reativos
                    ValueListenableBuilder<Duration>(
                      valueListenable: _elapsedNotifier,
                      builder: (context, elapsed, child) {
                        final goalSecs = active.goalDurationHours * 3600;
                        final elapsedSecs = elapsed.inSeconds;
                        final progress = goalSecs > 0 ? (elapsedSecs / goalSecs).clamp(0.0, 1.0) : 0.0;

                        return Column(
                          children: [
                            Text(
                              _formatDuration(elapsed),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Meta: ${active.goalDurationHours.toStringAsFixed(0)} horas",
                              style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),

                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.05),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 8,
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                "${(progress * 100).toStringAsFixed(0)}% concluído",
                                style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            _buildFastingStageCard(elapsed),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Botão Finalizar
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          provider.endFasting();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Jejum finalizado com sucesso!"),
                              backgroundColor: Colors.amber,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Finalizar Jejum",
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // CONFIGURAR JEJUM
              StatefulBuilder(
                builder: (context, setDialogState) {
                  return GlassCard(
                    padding: const EdgeInsets.all(20),
                    borderColor: Colors.white.withOpacity(0.04),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            "Iniciar Novo Jejum",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          "Protocolos Sugeridos",
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        _buildPopularProtocols((h) {
                          setDialogState(() {
                            _selectedGoalHours = h;
                          });
                        }),

                        const Text(
                          "Duração Meta",
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<double>(
                              value: _selectedGoalHours,
                              dropdownColor: const Color(0xff1c1c1e),
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              isExpanded: true,
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    _selectedGoalHours = val;
                                  });
                                }
                              },
                              items: [12.0, 14.0, 16.0, 18.0, 20.0, 23.0, 24.0, 36.0, 48.0]
                                  .map((h) => DropdownMenuItem(value: h, child: Text("$h horas")))
                                  .toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Botão Iniciar
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              provider.startFasting(_selectedGoalHours);
                              _elapsedNotifier.value = Duration.zero;
                              _startTimer();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.accentColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Iniciar Jejum",
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),

            // SEÇÃO DE ABSTINÊNCIAS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Abstinências Ativas",
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                TextButton.icon(
                  onPressed: () => _showAddAbstinenceDialog(context, provider),
                  icon: Icon(Icons.add_circle_outline, color: widget.accentColor, size: 16),
                  label: Text("Nova", style: TextStyle(color: widget.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                ),
              ],
            ),
            const SizedBox(height: 10),

            diet.abstinence.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        "Nenhuma abstinência registrada.",
                        style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic, fontSize: 12),
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
                          borderColor: Colors.white.withOpacity(0.04),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.title,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Tempo: $timeStr",
                                      style: TextStyle(color: widget.accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    if (a.notes != null && a.notes!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        a.notes!,
                                        style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.refresh, color: Colors.amber, size: 18),
                                    tooltip: "Reiniciar contador",
                                    onPressed: () => _confirmResetAbstinence(context, provider, a),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                    tooltip: "Excluir rastreador",
                                    onPressed: () => provider.deleteAbstinence(a.id),
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
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Histórico de Jejuns",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),

            diet.fasting.history.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        "Nenhum jejum concluído no histórico.",
                        style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
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
                      final startLocal = DateTime.tryParse(f.startTime)?.toLocal();
                      final dateStr = startLocal != null
                          ? "${startLocal.day.toString().padLeft(2, '0')}/${startLocal.month.toString().padLeft(2, '0')}"
                          : "";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          borderColor: reached ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        reached ? "Meta Cumprida 🎉" : "Jejum Incompleto ⚠️",
                                        style: TextStyle(
                                          color: reached ? Colors.green : Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Data: $dateStr",
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Fasting de ${goalHours.toStringAsFixed(0)}h",
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                              Text(
                                _formatDurationShort(diff),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
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

  void _showAddAbstinenceDialog(BuildContext context, TrackerProvider provider) {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          useBlur: true,
          borderColor: Colors.white.withOpacity(0.08),
          borderRadius: 20,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Nova Abstinência",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  hintText: "O que você vai parar? (ex: Açúcar)",
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  hintText: "Notas / Motivação (Opcional)",
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text("Cancelar", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      if (title.isNotEmpty) {
                        provider.addAbstinence(title, notesCtrl.text.trim());
                        Navigator.pop(dialogCtx);
                      }
                    },
                    child: Text("Iniciar", style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmResetAbstinence(BuildContext context, TrackerProvider provider, AbstinenceRecord a) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          useBlur: true,
          borderColor: Colors.white.withOpacity(0.08),
          borderRadius: 20,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Zerar Contador?",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                "Deseja realmente reiniciar o tempo de '${a.title}'? O contador recomeçará do zero.",
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text("Cancelar", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      provider.resetAbstinence(a.id);
                      Navigator.pop(dialogCtx);
                    },
                    child: const Text("Zerar", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
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

class _WaveCupWidgetState extends State<WaveCupWidget> with SingleTickerProviderStateMixin {
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
          math.sin((x / size.width) * waveFrequency + (waveValue * 2 * math.pi));
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
    return oldDelegate.progress != progress || oldDelegate.waveValue != waveValue;
  }
}

class HistoricoTab extends StatelessWidget {
  final Color accentColor;
  const HistoricoTab({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final history = provider.state?.dietHistory ?? {};
    
    final now = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    
    final List<String> dateStrings = last7Days.map((d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}").toList();
    final List<String> weekdaysShort = last7Days.map((d) {
      switch (d.weekday) {
        case 1: return "Seg";
        case 2: return "Ter";
        case 3: return "Qua";
        case 4: return "Qui";
        case 5: return "Sex";
        case 6: return "Sáb";
        case 7: return "Dom";
        default: return "";
      }
    }).toList();
    
    final List<double> calIntakes = [];
    final List<double> waterIntakes = [];
    
    double maxCal = 1000.0;
    double maxWater = 1000.0;
    
    final currentDiet = provider.state?.diet;
    for (int i = 0; i < 7; i++) {
      final dateStr = dateStrings[i];
      double cal = 0;
      double water = 0;
      
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      if (dateStr == todayStr && currentDiet != null) {
        cal = currentDiet.meals.fold<int>(0, (sum, m) => sum + m.calories).toDouble();
        water = currentDiet.waterIntakeMl.toDouble();
      } else if (history.containsKey(dateStr)) {
        cal = history[dateStr]!.caloriesIntake.toDouble();
        water = history[dateStr]!.waterIntakeMl.toDouble();
      }
      
      calIntakes.add(cal);
      waterIntakes.add(water);
      
      if (cal > maxCal) maxCal = cal;
      if (water > maxWater) maxWater = water;
    }
    
    maxCal *= 1.2;
    maxWater *= 1.2;
    
    final double calGoal = currentDiet?.caloriesGoal.toDouble() ?? 2000;
    final double waterGoal = currentDiet?.waterGoalMl.toDouble() ?? 2000;
    if (calGoal > maxCal) maxCal = calGoal * 1.2;
    if (waterGoal > maxWater) maxWater = waterGoal * 1.2;
    
    final double avgCals = calIntakes.reduce((a, b) => a + b) / 7;
    final double avgWater = waterIntakes.reduce((a, b) => a + b) / 7;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn("Média Calorias", "${avgCals.toStringAsFixed(0)} kcal"),
                  Container(width: 1, height: 40, color: Colors.white10),
                  _buildStatColumn("Média Hidratação", "${avgWater.toStringAsFixed(0)} ml"),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              "Histórico de Calorias (Kcal)",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxCal,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < 7) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(weekdaysShort[idx], style: const TextStyle(color: Colors.white54, fontSize: 10)),
                              );
                            }
                            return const Text("");
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: calGoal,
                          color: Colors.green.withOpacity(0.5),
                          strokeWidth: 2,
                          dashArray: [5, 5],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                            labelResolver: (line) => "Meta: ${calGoal.toInt()} kcal",
                          ),
                        ),
                      ],
                    ),
                    barGroups: List.generate(7, (i) {
                      final intake = calIntakes[i];
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: intake,
                            color: intake >= calGoal ? Colors.green : accentColor,
                            width: 14,
                            borderRadius: BorderRadius.circular(4),
                          )
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              "Histórico de Hidratação (ml)",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxWater,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < 7) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(weekdaysShort[idx], style: const TextStyle(color: Colors.white54, fontSize: 10)),
                              );
                            }
                            return const Text("");
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: waterGoal,
                          color: Colors.blue.withOpacity(0.5),
                          strokeWidth: 2,
                          dashArray: [5, 5],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: const TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold),
                            labelResolver: (line) => "Meta: ${waterGoal.toInt()} ml",
                          ),
                        ),
                      ],
                    ),
                    barGroups: List.generate(7, (i) {
                      final intake = waterIntakes[i];
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: intake,
                            color: intake >= waterGoal ? Colors.blue : Colors.blue.withOpacity(0.6),
                            width: 14,
                            borderRadius: BorderRadius.circular(4),
                          )
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String val) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
