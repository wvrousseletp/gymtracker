import 'dart:convert';
import 'dart:io';
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

  /// Tenta obter a chave do Gemini do documento '/config/gemini' do Firestore.
  Future<String?> _getApiKey() async {
    try {
      final doc = await _firestore.collection('config').doc('gemini').get();
      if (doc.exists) {
        var key = doc.data()?['apiKey'] as String?;
        if (key != null) {
          key = key.trim();
          // Remove aspas caso o usuário tenha colado com aspas por engano
          if (key.startsWith('"') && key.endsWith('"') && key.length > 2) {
            key = key.substring(1, key.length - 1);
          }
          return key;
        }
      }
    } catch (e) {
      debugPrint('[FoodService] Erro ao obter API Key do Firestore: $e');
    }
    return null;
  }

  /// Consulta a IA do Gemini para obter a tabela nutricional estimada para o alimento.
  Future<FoodItem?> fetchFoodNutritionFromAI(String foodQuery) async {
    try {
      final apiKey = await _getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('[FoodService] Gemini API Key não configurada no Firestore.');
        return null;
      }

      final prompt = '''
Aja como um banco de dados de alimentos profissional. Retorne os dados nutricionais estimados por 100g ou 1 unidade padrão do alimento solicitado.
Você DEVE responder APENAS com um objeto JSON válido, sem markdown, sem explicações adicionais, contendo exatamente os seguintes campos:
{
  "name": "Nome formatado do Alimento",
  "calories": 150,
  "protein": 20.5,
  "carbs": 10.0,
  "fat": 3.5,
  "servingSize": 100,
  "servingUnit": "g"
}
Caso o alimento seja líquido, use "ml" como servingUnit. Caso seja um item que normalmente se consome por unidade (ex: ovo), use "unidade" com servingSize 1.
Alimento pesquisado: $foodQuery
''';

      final client = HttpClient();
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');
      
      final request = await client.postUrl(uri);
      request.headers.set('content-type', 'application/json');
      request.add(utf8.encode(jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "responseMimeType": "application/json"
        }
      })));

      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint('[FoodService] Erro na API do Gemini: Código ${response.statusCode}');
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> decoded = jsonDecode(responseBody);
      
      final String? jsonText = decoded['candidates']?[0]?['content']?[0]?['text'];
      if (jsonText == null) return null;

      final Map<String, dynamic> foodJson = jsonDecode(jsonText.trim());
      
      return FoodItem(
        id: '',
        name: foodJson['name'] ?? foodQuery,
        searchName: (foodJson['name'] ?? foodQuery).toString().toLowerCase(),
        calories: (foodJson['calories'] as num?)?.toInt() ?? 0,
        protein: (foodJson['protein'] as num?)?.toDouble() ?? 0.0,
        carbs: (foodJson['carbs'] as num?)?.toDouble() ?? 0.0,
        fat: (foodJson['fat'] as num?)?.toDouble() ?? 0.0,
        servingSize: (foodJson['servingSize'] as num?)?.toInt() ?? 100,
        servingUnit: foodJson['servingUnit'] ?? 'g',
      );
    } catch (e) {
      debugPrint('[FoodService] Erro ao consultar IA do Gemini: $e');
      return null;
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
