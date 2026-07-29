import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
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

    final googleAI = FirebaseAI.googleAI(auth: FirebaseAuth.instance);

    final model = googleAI.generativeModel(
      model: 'gemini-flash-latest',
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            "suggestions": Schema.array(
              description: "Lista de sugestões por exercício",
              items: Schema.object(
                properties: {
                  "exerciseName": Schema.string(
                      description: "Nome do exercício"),
                  "suggestion": Schema.string(
                      description:
                          "Uma dica curta e acionável com sugestão de carga/repetição (máx 2 frases). Ex: 'Tente 80kg x 12. Aumente as repetições pois houve falha no último treino.'"),
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

    try {
      final response =
          await model.generateContent([Content.text(buffer.toString())]);
      final text = response.text;

      if (text != null && text.isNotEmpty) {
        final data = jsonDecode(text) as Map<String, dynamic>;
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
    } catch (e) {
      // ignore in production — card will show empty state
    }

    return {};
  }
}
