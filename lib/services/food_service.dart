
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/food_item.dart';
import '../models/favorite_food.dart';
import '../models/meal_preset.dart';

class FoodService {
  FoodService._privateConstructor();
  static final FoodService instance = FoodService._privateConstructor();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Busca alimentos no banco compartilhado do Firestore por nome (prefixo).
  Future<List<FoodItem>> searchFoods(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final searchLower = query.trim().toLowerCase();
      final snapshot = await _firestore
          .collection('foods')
          .where('searchName', isGreaterThanOrEqualTo: searchLower)
          .where('searchName', isLessThanOrEqualTo: '$searchLower\uf8ff')
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => FoodItem.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('[FoodService] Erro ao buscar alimentos: $e');
      return [];
    }
  }

  /// Cadastra um novo alimento no banco global.
  Future<bool> addFood(FoodItem food) async {
    try {
      await _firestore.collection('foods').doc(food.id.isNotEmpty ? food.id : null).set(food.toJson());
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
