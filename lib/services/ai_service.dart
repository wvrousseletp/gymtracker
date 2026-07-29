import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import '../models/workout_log.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  /// Solicita sugestões personalizadas de treino para os exercícios planejados.
  Future<Map<String, String>> generateWorkoutSuggestions({
    required List<String> plannedExercises,
    required List<WorkoutLog> recentHistory,
  }) async {
    if (plannedExercises.isEmpty) return {};

    try {
      final model = FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-1.5-flash',
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(
            properties: {
              "suggestions": Schema.array(
                description: "Lista de sugestões por exercício",
                items: Schema.object(
                  properties: {
                    "exerciseName": Schema.string(description: "Nome do exercício"),
                    "suggestion": Schema.string(
                        description: "Dica curta (máx 2 frases)."),
                  },
                  requiredProperties: ["exerciseName", "suggestion"],
                ),
              ),
            },
            requiredProperties: ["suggestions"],
          ),
        ),
      );

      final buffer = StringBuffer();
      buffer.writeln("Você é um personal trainer especialista em hipertrofia e sobrecarga progressiva.");
      buffer.writeln("O usuário fará o seguinte treino hoje: ${plannedExercises.join(', ')}");
      buffer.writeln("Aqui está o histórico recente do usuário para esses exercícios:");

      bool hasHistory = false;
      for (var log in recentHistory) {
        for (var ex in log.exercises) {
          if (plannedExercises.contains(ex.name) && ex.completedSets > 0) {
            hasHistory = true;
            buffer.writeln(
                "- ${log.date}: ${ex.name} -> ${ex.completedSets} séries de ${ex.reps} reps com ${ex.weight}kg.");
          }
        }
      }

      if (!hasHistory) {
        buffer.writeln("Nenhum histórico encontrado. Forneça sugestão genérica de hipertrofia para cada exercício.");
      } else {
        buffer.writeln("Com base no histórico, forneça meta de carga e repetições usando sobrecarga progressiva.");
      }

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
      return {};
    }
  }

  /// Solicita uma análise profunda do histórico de um único exercício para a Central do Exercício.
  Future<String?> analyzeExerciseHistory({
    required String exerciseName,
    required List<WorkoutLog> exerciseHistory,
    bool isCardio = false,
  }) async {
    if (exerciseHistory.isEmpty) return null;

    try {
      final model = FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-1.5-flash',
        generationConfig: GenerationConfig(
          temperature: 0.4,
          maxOutputTokens: 500,
        ),
      );

      final buffer = StringBuffer();
      if (isCardio) {
        buffer.writeln("Você é um treinador de elite especialista em endurance, corrida e cardio.");
      } else {
        buffer.writeln("Você é um treinador de elite especialista em musculação e biomecânica.");
      }
      buffer.writeln("Estou analisando meu histórico do exercício: $exerciseName.");
      buffer.writeln("Aqui estão as minhas sessões de treino passadas em ordem decrescente (da mais recente para a mais antiga):");

      final logsToAnalyze = exerciseHistory.take(15).toList();

      for (var log in logsToAnalyze) {
        for (var ex in log.exercises) {
          if (ex.name == exerciseName) {
            if (isCardio) {
              String cardioStats = "";
              if (ex.performedCardios != null && ex.performedCardios!.isNotEmpty) {
                final pcs = ex.performedCardios!.where((c) => c != null).toList();
                for (var pc in pcs) {
                  final dist = pc!.distanceKm;
                  final dur = pc.durationSeconds ~/ 60;
                  String paceStr = "";
                  if (dist > 0 && dur > 0) {
                     final pace = dur / dist;
                     final m = pace.floor();
                     final s = ((pace - m) * 60).round();
                     paceStr = " Pace médio: $m:${s.toString().padLeft(2, '0')}/km.";
                  }
                  cardioStats += " [${dist.toStringAsFixed(2)}km em ${dur}m.$paceStr]";
                }
              }
              if (cardioStats.isEmpty) {
                 cardioStats = " [${ex.weight}km em ${ex.reps}m]";
              }
              buffer.writeln("- ${log.date}:$cardioStats RPE do exercício: ${ex.rpe}. Batimentos do treino: ${log.avgHeartRate ?? 'N/A'}.");
            } else {
              buffer.writeln("- ${log.date}: ${ex.completedSets} séries. Peso máximo do dia: ${ex.weight}kg. Reps: ${ex.reps}. RPE: ${ex.rpe}. Falha relatada: ${ex.failureReport != null && ex.failureReport!.contains(true) ? 'Sim' : 'Não'}.");
            }
          }
        }
      }

      buffer.writeln("\nFaça uma análise rápida, direta e motivadora (no máximo 3 ou 4 frases curtas).");
      if (isCardio) {
        buffer.writeln("Identifique tendências (melhora de pace, aumento de distância ou resistência) e me dê uma dica prática e acionável para o meu próximo treino desse exercício. Não use Markdown exagerado, apenas texto limpo.");
      } else {
        buffer.writeln("Identifique tendências (estagnação, progressão de volume ou carga) e me dê uma dica prática e acionável para o meu próximo treino desse exercício. Não use Markdown exagerado, apenas texto limpo.");
      }

      final response = await model.generateContent([
        Content.text(buffer.toString())
      ]);

      return response.text?.trim();
    } catch (e) {
      debugPrint('AI Exception (analyzeExerciseHistory): $e');
      return null;
    }
  }
}
