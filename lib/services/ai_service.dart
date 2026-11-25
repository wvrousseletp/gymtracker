import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_item.dart';
import '../models/workout_log.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  static const String _cachedKeyPref = 'cached_gemini_api_key_v1';
  static const String _cachedModelPref = 'cached_gemini_model_v1';
  static const String _defaultModel = 'gemini-flash-latest';

  String? _memoryApiKey;
  String? _memoryModel;
  bool _cloudConfigChecked = false;

  static String get _fallbackApiKey => utf8.decode(base64.decode(
      'QVEuQWI4Uk42SmJIcjN3MUIySG0tOElyakJ4SGttZnRtVVFCUmI2V3hwYlQxOHFVeUd1OFE='));

  /// Obtém a chave e o modelo do Gemini priorizando `/config/gemini` no Firestore
  /// (com cache em SharedPreferences e fallback local seguro).
  Future<({String apiKey, String model})> _resolveConfig() async {
    if (_memoryApiKey != null && _memoryApiKey!.isNotEmpty) {
      return (apiKey: _memoryApiKey!, model: _memoryModel ?? _defaultModel);
    }

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_cachedKeyPref);
      final savedModel = prefs.getString(_cachedModelPref);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        _memoryApiKey = savedKey.trim();
        _memoryModel =
            (savedModel != null && savedModel.trim().isNotEmpty)
                ? savedModel.trim()
                : _defaultModel;
      }
    } catch (_) {}

    if (!_cloudConfigChecked) {
      _cloudConfigChecked = true;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('config')
            .doc('gemini')
            .get()
            .timeout(const Duration(seconds: 3));
        if (doc.exists) {
          final data = doc.data();
          final remoteKey =
              (data?['apiKey'] ?? data?['key'])?.toString().trim();
          final remoteModel = data?['model']?.toString().trim();
          if (remoteKey != null && remoteKey.isNotEmpty) {
            _memoryApiKey = remoteKey;
            await prefs?.setString(_cachedKeyPref, remoteKey);
          }
          if (remoteModel != null && remoteModel.isNotEmpty) {
            _memoryModel = remoteModel;
            await prefs?.setString(_cachedModelPref, remoteModel);
          }
        }
      } catch (e) {
        debugPrint('[AIService] Fallback para chave local (config/gemini): $e');
      }
    }

    final resolvedKey = (_memoryApiKey != null && _memoryApiKey!.isNotEmpty)
        ? _memoryApiKey!
        : _fallbackApiKey;
    final resolvedModel = (_memoryModel != null && _memoryModel!.isNotEmpty)
        ? _memoryModel!
        : _defaultModel;
    return (apiKey: resolvedKey, model: resolvedModel);
  }

  /// Estima calorias e macronutrientes de uma refeição descrita em linguagem natural.
  Future<FoodItem?> estimateMealMacros(String mealDescription) async {
    final trimmed = mealDescription.trim();
    if (trimmed.isEmpty) return null;

    try {
      final cfg = await _resolveConfig();
      final model = GenerativeModel(
        model: cfg.model,
        apiKey: cfg.apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.2,
          responseMimeType: 'application/json',
          maxOutputTokens: 1024,
        ),
      );

      final prompt = '''
Você é um nutricionista esportivo especialista em tabelas nutricionais brasileiras (TACO / IBGE / USDA).
Analise a refeição ou alimento descrito pelo usuário em Português do Brasil: "$trimmed".
Estime com precisão realista os valores nutricionais TOTAIS da porção descrita.
Retorne ESTRITAMENTE um objeto JSON válido (sem markdown) no formato:
{
  "name": "Nome curto e claro da refeição/alimento em pt-BR",
  "calories": 450,
  "protein": 32.5,
  "carbs": 40.0,
  "fat": 14.0,
  "servingSize": 300,
  "servingUnit": "g"
}
Regras:
- "calories" deve ser inteiro (kcal totais da porção descrita).
- "protein", "carbs" e "fat" em gramas (números decimais).
- "servingSize" deve ser o peso/volume aproximado total em gramas ou ml (inteiro > 0, ex: 100, 250, 350).
- "servingUnit" deve ser "g", "ml" ou "porção".
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.isEmpty) return null;

      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      final parsed =
          jsonDecode(text.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
      final name = (parsed['name']?.toString().trim().isNotEmpty ?? false)
          ? parsed['name'].toString().trim()
          : trimmed;
      final calories = (parsed['calories'] as num?)?.round() ?? 0;
      final protein = (parsed['protein'] as num?)?.toDouble() ?? 0.0;
      final carbs = (parsed['carbs'] as num?)?.toDouble() ?? 0.0;
      final fat = (parsed['fat'] as num?)?.toDouble() ?? 0.0;
      final servingSize =
          ((parsed['servingSize'] as num?)?.round() ?? 100).clamp(1, 5000);
      final servingUnit = parsed['servingUnit']?.toString().trim() ?? 'g';

      return FoodItem(
        id: '', // ID vazio sinaliza alimento estimado pela IA
        name: name,
        searchName: name.toLowerCase(),
        calories: calories,
        protein: double.parse(protein.toStringAsFixed(1)),
        carbs: double.parse(carbs.toStringAsFixed(1)),
        fat: double.parse(fat.toStringAsFixed(1)),
        servingSize: servingSize,
        servingUnit: servingUnit,
      );
    } catch (e) {
      debugPrint('AI Exception (estimateMealMacros): $e');
      return null;
    }
  }

  /// Solicita sugestões personalizadas de treino para os exercícios planejados.
  Future<Map<String, String>> generateWorkoutSuggestions({
    required List<String> plannedExercises,
    required List<WorkoutLog> recentHistory,
  }) async {
    if (plannedExercises.isEmpty) return {};

    try {
      final cfg = await _resolveConfig();
      final model = GenerativeModel(
        model: cfg.model,
        apiKey: cfg.apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          maxOutputTokens: 4000,
        ),
      );

      final buffer = StringBuffer();
      buffer.writeln("Você é um personal trainer de elite especialista em hipertrofia, fisiologia do exercício e sobrecarga progressiva.");
      buffer.writeln("Você responde EXCLUSIVAMENTE em Português do Brasil (pt-BR).");
      buffer.writeln("O usuário fará o seguinte treino hoje: ${plannedExercises.join(', ')}");
      buffer.writeln("Aqui está o histórico recente do usuário para esses exercícios:");

      bool hasHistory = false;
      for (var log in recentHistory) {
        if (log.isRestDayLog) continue;
        for (var ex in log.exercises) {
          if (plannedExercises.contains(ex.name) && ex.completedSets > 0) {
            hasHistory = true;
            buffer.writeln(
                "- Data: ${log.date} | Exercício: ${ex.name} -> ${ex.completedSets} séries de ${ex.reps} reps com ${ex.weight}kg (RPE: ${ex.rpe}).");
          }
        }
      }

      if (!hasHistory) {
        buffer.writeln("Nenhum histórico recente encontrado. Forneça uma orientação prática e direta de hipertrofia para cada exercício (faixa de 8-12 reps, cadência controlada e proximidade da falha).");
      } else {
        buffer.writeln("Com base no histórico e no intervalo entre treinos, forneça uma meta clara de sobrecarga progressiva para hipertrofia (ajuste de peso, aumento de repetições ou consolidação da carga atual com máxima amplitude).");
      }

      buffer.writeln("Retorne estritamente em formato JSON com a seguinte estrutura, sem blocos markdown adicionais além do JSON:");
      buffer.writeln('{ "suggestions": [ { "exerciseName": "Nome", "suggestion": "Sugestão em pt-BR focada em hipertrofia" } ] }');

      final response = await model.generateContent([
        Content.text(buffer.toString())
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) return {};

      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return {};

      final jsonStr = text.substring(jsonStart, jsonEnd + 1);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final suggestionsArray = parsed['suggestions'] as List<dynamic>? ?? [];

      final Map<String, String> result = {};
      for (var item in suggestionsArray) {
        final exName = item['exerciseName'] as String?;
        final suggestion = item['suggestion'] as String?;
        if (exName != null && suggestion != null) {
          result[exName] = suggestion;
        }
      }
      return result;
    } catch (e) {
      debugPrint('AI Exception (generateWorkoutSuggestions): $e');
      return {"Erro": "Falha na IA: $e"};
    }
  }

  /// Solicita uma análise profunda do histórico de um único exercício para a Central do Exercício.
  Future<String> analyzeExerciseHistory({
    required String exerciseName,
    required List<WorkoutLog> exerciseHistory,
    bool isCardio = false,
  }) async {
    if (exerciseHistory.isEmpty) return "Sem dados suficientes para análise.";

    try {
      final cfg = await _resolveConfig();
      final model = GenerativeModel(
        model: cfg.model,
        apiKey: cfg.apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.5,
          maxOutputTokens: 4000,
        ),
      );

      final buffer = StringBuffer();
      buffer.writeln("Você é meu personal trainer de elite, especialista em hipertrofia e fisiologia do exercício.");
      buffer.writeln("Você fala EXCLUSIVAMENTE em Português do Brasil (pt-BR).");
      buffer.writeln("Fale diretamente comigo como um treinador genial, direto ao ponto, técnico e prático.");
      buffer.writeln("Exercício em análise: $exerciseName.");
      buffer.writeln("Histórico recente de treinos neste exercício (do mais recente para o mais antigo):");

      final logsToAnalyze =
          exerciseHistory.where((l) => !l.isRestDayLog).take(15).toList();

      for (var log in logsToAnalyze) {
        for (var ex in log.exercises) {
          if (ex.name == exerciseName) {
            if (isCardio) {
              String cardioStats = "";
              if (ex.performedCardios != null && ex.performedCardios!.any((c) => c != null)) {
                final pcs = ex.performedCardios!.where((c) => c != null).toList();
                for (var pc in pcs) {
                  final dist = pc!.distanceKm;
                  final dur = pc.durationSeconds ~/ 60;
                  String paceStr = "";
                  if (dist > 0 && dur > 0) {
                     final pace = dur / dist;
                     final m = pace.floor();
                     final s = ((pace - m) * 60).round();
                     paceStr = " Pace: $m:${s.toString().padLeft(2, '0')}/km.";
                  }
                  cardioStats += " [${dist.toStringAsFixed(2)}km em ${dur}m.$paceStr]";
                }
              }
              if (cardioStats.isEmpty) {
                 cardioStats = " [${ex.weight}km em ${ex.reps}m]";
              }
              buffer.writeln("- Data: ${log.date}. Cardio:$cardioStats. RPE: ${ex.rpe}. Batimentos: ${log.avgHeartRate ?? 'N/A'}.");
            } else {
              buffer.writeln("- Data: ${log.date}: ${ex.completedSets} séries de ${ex.reps} reps com ${ex.weight}kg. Esforço (RPE): ${ex.rpe}. Falha atingida: ${ex.failureReport != null && ex.failureReport!.contains(true) ? 'Sim' : 'Não'}.");
            }
          }
        }
      }

      buffer.writeln("\nSua tarefa e regras obrigatórias:");
      buffer.writeln("1. Analise a evolução de carga, repetições, proximidade da falha e o intervalo de recuperação entre treinos ao longo do tempo.");
      buffer.writeln("2. O objetivo absoluto é HIPERTROFIA MÁXIMA com sobrecarga progressiva estruturada e execução de alta qualidade.");
      buffer.writeln("3. Se o histórico indicar que o estímulo já está adaptado, sugira a progressão exata (ex: subir 1kg a 2kg, buscar +1 ou +2 repetições na mesma carga ou aumentar o tempo sob tensão na fase excêntrica).");
      buffer.writeln("4. Se for melhor consolidar neuromuscularmente antes de subir a carga, explique de forma técnica e oriente por quantas sessões manter.");
      buffer.writeln("5. Responda em 1 a 2 parágrafos diretos, inspiradores, inteligentes e 100% completos.");
      buffer.writeln("6. PROIBIDO usar Markdown (sem asteriscos **, sem títulos # e sem tópicos em marcadores). Escreva texto corrido, limpo e profissional.");

      final response = await model.generateContent([
        Content.text(buffer.toString())
      ]);

      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return "Não foi possível gerar a análise.";
      }
      return text;
    } catch (e) {
      debugPrint('AI Exception (analyzeExerciseHistory): $e');
      return "Erro ao analisar exercício: $e";
    }
  }

  /// Mantido para compatibilidade retroativa.
  Stream<String> analyzeExerciseHistoryStream({
    required String exerciseName,
    required List<WorkoutLog> exerciseHistory,
    bool isCardio = false,
  }) async* {
    final result = await analyzeExerciseHistory(
      exerciseName: exerciseName,
      exerciseHistory: exerciseHistory,
      isCardio: isCardio,
    );
    yield result;
  }
}
