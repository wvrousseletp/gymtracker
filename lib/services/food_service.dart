import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/food_item.dart';
import '../models/favorite_food.dart';
import '../models/meal_preset.dart';
import '../utils/food_presets_data.dart';

class FoodService {
  FoodService._privateConstructor();
  static final FoodService instance = FoodService._privateConstructor();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final List<FoodItem> _customCachedFoods = [];

  /// Normaliza texto removendo acentos/diacríticos e espaços extras.
  static String normalizeSearchText(String input) {
    const withAccents =
        'àáâãäåèéêëìíîïòóôõöùúûüçñýÿÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÇÑÝ';
    const withoutAccents =
        'aaaaaaeeeeiiiiooooouuuucnyyAAAAAAEEEEIIIIOOOOOUUUUCNY';
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      final idx = withAccents.indexOf(ch);
      buffer.write(idx >= 0 ? withoutAccents[idx] : ch);
    }
    return buffer
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Pontua um alimento contra a consulta normalizada (menor = mais relevante, null = não casa).
  static int? matchScore(FoodItem item, String rawQuery) {
    final normQuery = normalizeSearchText(rawQuery);
    if (normQuery.isEmpty) return null;

    final normName = normalizeSearchText(item.name);
    final normSearch = normalizeSearchText(item.searchName);
    final target = normName.isNotEmpty ? normName : normSearch;

    if (target == normQuery) return 0;
    if (target.startsWith(normQuery)) return 1;

    final tokens =
        normQuery.split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;

    final allMatch = tokens.every(
        (token) => target.contains(token) || normSearch.contains(token));
    if (!allMatch) return null;

    // Prioriza quando o primeiro token inicia alguma palavra do alimento
    final words = target.split(' ');
    if (words.any((w) => w.startsWith(tokens.first))) {
      return 2;
    }
    return 3;
  }

  /// Filtra uma lista de alimentos localmente com tolerância a acentos e palavras fora de ordem.
  static List<FoodItem> filterFoodsLocally(
      Iterable<FoodItem> source, String query,
      {int limit = 25}) {
    final scored = <({FoodItem item, int score})>[];
    final seenNames = <String>{};

    for (final item in source) {
      final key = normalizeSearchText(item.name);
      if (key.isEmpty || seenNames.contains(key)) continue;
      final score = matchScore(item, query);
      if (score != null) {
        seenNames.add(key);
        scored.add((item: item, score: score));
      }
    }

    scored.sort((a, b) {
      final cmp = a.score.compareTo(b.score);
      if (cmp != 0) return cmp;
      return a.item.name.length.compareTo(b.item.name.length);
    });

    return scored.take(limit).map((e) => e.item).toList();
  }

  /// Busca alimentos combinando Firestore (com e sem acento) + catálogo local semeado (substring/sem acento).
  Future<List<FoodItem>> searchFoods(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final remoteItems = <FoodItem>[];
    try {
      final rawLower = trimmed.toLowerCase();
      final normLower = normalizeSearchText(trimmed);

      final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        _firestore
            .collection('foods')
            .where('searchName', isGreaterThanOrEqualTo: rawLower)
            .where('searchName', isLessThanOrEqualTo: '$rawLower\uf8ff')
            .limit(20)
            .get(),
      ];

      if (normLower != rawLower && normLower.isNotEmpty) {
        futures.add(
          _firestore
              .collection('foods')
              .where('searchName', isGreaterThanOrEqualTo: normLower)
              .where('searchName', isLessThanOrEqualTo: '$normLower\uf8ff')
              .limit(20)
              .get(),
        );
      }

      final snapshots = await Future.wait(futures);
      for (final snap in snapshots) {
        for (final doc in snap.docs) {
          final parsed = FoodItem.fromJson(doc.data(), doc.id);
          remoteItems.add(parsed);
        }
      }
    } catch (e) {
      debugPrint('[FoodService] Erro ao buscar alimentos remotos (usando busca local): $e');
    }

    final combinedPool = <FoodItem>[
      ...remoteItems,
      ..._customCachedFoods,
      ...presetFoods100,
    ];

    return filterFoodsLocally(combinedPool, trimmed, limit: 25);
  }

  /// Cadastra um novo alimento no banco global (com searchName normalizado).
  Future<bool> addFood(FoodItem food) async {
    final normalizedFood = FoodItem(
      id: food.id,
      name: food.name,
      searchName: normalizeSearchText(
          food.searchName.isNotEmpty ? food.searchName : food.name),
      calories: food.calories,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
      servingSize: food.servingSize,
      servingUnit: food.servingUnit,
    );
    _customCachedFoods.removeWhere(
        (f) => normalizeSearchText(f.name) == normalizeSearchText(food.name));
    _customCachedFoods.insert(0, normalizedFood);
    try {
      await _firestore
          .collection('foods')
          .doc(normalizedFood.id.isNotEmpty ? normalizedFood.id : null)
          .set(normalizedFood.toJson());
      return true;
    } catch (e) {
      debugPrint('[FoodService] Erro ao adicionar alimento: $e');
      return false;
    }
  }



  // --- MÉTODOS DE FAVORITOS (Salvo sob /users/{userId}/favorite_foods) ---

  Future<List<FavoriteFood>> getFavorites(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorite_foods')
          .get();

      return snapshot.docs
          .map((doc) => FavoriteFood.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('[FoodService] Erro ao buscar favoritos: $e');
      return [];
    }
  }

  Future<void> addFavorite(String userId, FavoriteFood favorite) async {
    if (userId.isEmpty) return;
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('favorite_foods')
          .doc(favorite.id.isNotEmpty ? favorite.id : null);
      await docRef.set(favorite.toJson());
    } catch (e) {
      debugPrint('[FoodService] Erro ao adicionar favorito: $e');
    }
  }

  Future<void> deleteFavorite(String userId, String favoriteId) async {
    if (userId.isEmpty || favoriteId.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorite_foods')
          .doc(favoriteId)
          .delete();
    } catch (e) {
      debugPrint('[FoodService] Erro ao deletar favorito: $e');
    }
  }

  // --- MÉTODOS DE COMBOS/PRESETS (Salvo sob /users/{userId}/presets) ---

  Future<List<MealPreset>> getPresets(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('presets')
          .get();

      return snapshot.docs
          .map((doc) => MealPreset.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('[FoodService] Erro ao buscar presets: $e');
      return [];
    }
  }

  Future<void> addPreset(String userId, MealPreset preset) async {
    if (userId.isEmpty) return;
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('presets')
          .doc(preset.id.isNotEmpty ? preset.id : null);
      await docRef.set(preset.toJson());
    } catch (e) {
      debugPrint('[FoodService] Erro ao adicionar preset: $e');
    }
  }

  Future<void> deletePreset(String userId, String presetId) async {
    if (userId.isEmpty || presetId.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('presets')
          .doc(presetId)
          .delete();
    } catch (e) {
      debugPrint('[FoodService] Erro ao deletar preset: $e');
    }
  }
}
