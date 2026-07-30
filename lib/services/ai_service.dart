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

      buffer.writeln("Retorne estritamente em formato JSON com a seguinte estrutura:");
      buffer.writeln('{ "suggestions": [ { "exerciseName": "Nome", "suggestion": "Dica" } ] }');

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

  /// Solicita uma análise profunda do histórico de um único exercício para a Central do Exercício em Stream.
  Stream<String> analyzeExerciseHistoryStream({
    required String exerciseName,
    required List<WorkoutLog> exerciseHistory,
    bool isCardio = false,
  }) async* {
    if (exerciseHistory.isEmpty) return;

    try {
      final model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.4,
          maxOutputTokens: 500,
        ),
      );

      final buffer = StringBuffer();
      if (isCardio) {
        buffer.writeln("Você é meu treinador pessoal de cardio. Fale DIRETAMENTE comigo, como se estivesse me mandando uma mensagem rápida no WhatsApp.");
      } else {
        buffer.writeln("Você é meu treinador pessoal de musculação e biomecânica. Fale DIRETAMENTE comigo, como se estivesse me mandando uma mensagem rápida no WhatsApp.");
      }
      buffer.writeln("NÃO se apresente. NÃO diga 'como seu treinador' ou 'vejo que você...'. Vá direto ao ponto.");
      buffer.writeln("O foco agora é o exercício: $exerciseName.");
      buffer.writeln("Este é o meu histórico recente de treinos neste exercício (do mais recente para o mais antigo):");

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
              buffer.writeln("- Data: ${log.date}. Desempenho:$cardioStats. RPE (esforço): ${ex.rpe}. Batimentos: ${log.avgHeartRate ?? 'N/A'}.");
            } else {
              buffer.writeln("- Data: ${log.date}. Volume: ${ex.completedSets} séries de ${ex.reps} reps. Carga utilizada: ${ex.weight}kg. RPE (esforço): ${ex.rpe}. Chegou à falha? ${ex.failureReport != null && ex.failureReport!.contains(true) ? 'Sim' : 'Não'}.");
            }
          }
        }
      }

      buffer.writeln("\nSua tarefa: Analisar os dados acima e me dar um insight.");
      buffer.writeln("Regras estritas:");
      buffer.writeln("1. Seja breve, direto e natural (máximo 2-3 parágrafos curtos).");
      buffer.writeln("2. Destaque uma tendência que você notou (estagnação, progressão de carga, melhora, etc.).");
      buffer.writeln("3. Dê UMA sugestão clara e prática para o treino de HOJE (ex: tentar aumentar 2kg, focar na técnica, fazer mais reps, ou descansar um pouco se o esforço anterior foi extremo).");
      buffer.writeln("4. PROIBIDO USAR MARKDOWN (nada de *, **, #, ou listas pontilhadas). Escreva um texto fluido e contínuo.");

      final responseStream = model.generateContentStream([
        Content.text(buffer.toString())
      ]);

      await for (final chunk in responseStream) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      debugPrint('AI Exception (analyzeExerciseHistoryStream): $e');
      yield '\n\nErro na IA: $e';
    }
  }
}
