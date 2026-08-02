import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/workout_log.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  static String get _apiKey =>
      utf8.decode(base64.decode('QVEuQWI4Uk42SmJIcjN3MUIySG0tOElyakJ4SGttZnRtVVFCUmI2V3hwYlQxOHFVeUd1OFE='));

  /// Solicita sugestões personalizadas de treino para os exercícios planejados.
  Future<Map<String, String>> generateWorkoutSuggestions({
    required List<String> plannedExercises,
    required List<WorkoutLog> recentHistory,
  }) async {
    if (plannedExercises.isEmpty) return {};

    try {
      final model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: _apiKey,
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
      final model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: _apiKey,
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
