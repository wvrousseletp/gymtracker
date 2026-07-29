import 'dart:convert';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_log.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  /// Solicita sugestões personalizadas de treino para os exercícios planejados.
  ///
  /// [plannedExercises] é a lista de nomes dos exercícios planejados para o dia.
  /// [recentHistory] é a lista de [WorkoutLog] dos últimos meses.
  /// Retorna um mapa de NomeExercício → Texto da Sugestão.
  Future<Map<String, String>> generateWorkoutSuggestions({
    required List<String> plannedExercises,
    required List<WorkoutLog> recentHistory,
  }) async {
    if (plannedExercises.isEmpty) return {};

    final vertexAI = FirebaseVertexAI.instanceFor(auth: FirebaseAuth.instance);

    final model = vertexAI.generativeModel(
      model: 'gemini-1.5-flash',
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final buffer = StringBuffer();
    buffer.writeln(
        "Você é um personal trainer especialista em hipertrofia e sobrecarga progressiva.");
    buffer.writeln(
        "O usuário fará o seguinte treino hoje: ${plannedExercises.join(', ')}");
    buffer.writeln(
        "Aqui está o histórico recente do usuário para esses exercícios:");

    bool hasHistory = false;
    for (var log in recentHistory) {
      for (var ex in log.exercises) {
        if (plannedExercises.contains(ex.name) && ex.completedSets > 0) {
          hasHistory = true;
          final notesPart =
              ex.notes.isNotEmpty ? ' Notas: ${ex.notes}' : '';
          buffer.writeln(
              "- ${log.date}: ${ex.name} -> ${ex.completedSets} séries de ${ex.reps} reps com ${ex.weight}kg.$notesPart");
        }
      }
    }

    if (!hasHistory) {
      buffer.writeln(
          "Nenhum histórico recente encontrado para esses exercícios. Forneça uma sugestão genérica de hipertrofia para cada um.");
    } else {
      buffer.writeln(
          "Com base no histórico, forneça uma meta de carga e repetições para o treino de hoje usando os princípios de sobrecarga progressiva.");
    }

    buffer.writeln(
        "\nResponda APENAS com um JSON válido no seguinte formato, sem nenhum texto adicional:");
    buffer.writeln('{"suggestions": [');
    buffer.writeln('  {"exerciseName": "Nome do Exercício", "suggestion": "Dica curta (máx 2 frases)."}');
    buffer.writeln(']}');

    try {
      final response =
          await model.generateContent([Content.text(buffer.toString())]);
      final text = response.text;

      if (text != null && text.isNotEmpty) {
        // Extrai o JSON mesmo se vier com texto ao redor
        final jsonStart = text.indexOf('{');
        final jsonEnd = text.lastIndexOf('}');
        if (jsonStart == -1 || jsonEnd == -1) return {};

        final jsonStr = text.substring(jsonStart, jsonEnd + 1);
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final suggestionsArray = data['suggestions'] as List<dynamic>? ?? [];

        final Map<String, String> result = {};
        for (var item in suggestionsArray) {
          final exName = item['exerciseName'] as String?;
          final suggestion = item['suggestion'] as String?;
          if (exName != null && suggestion != null) {
            result[exName] = suggestion;
          }
        }
        return result;
      }
    } catch (_) {
      // ignore — card mostrará estado vazio
    }

    return {};
  }
}
