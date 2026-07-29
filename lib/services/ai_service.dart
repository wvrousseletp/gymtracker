import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_log.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  /// Requests personalized workout suggestions for the planned exercises.
  /// 
  /// [plannedExercises] is a list of exercise names planned for the day.
  /// [recentHistory] is a list of [WorkoutLog] from the last ~3 months.
  /// Returns a map of ExerciseName -> Suggestion Text.
  Future<Map<String, String>> generateWorkoutSuggestions({
    required List<String> plannedExercises,
    required List<WorkoutLog> recentHistory,
  }) async {
    if (plannedExercises.isEmpty) return {};

    final googleAI = FirebaseAI.googleAI(auth: FirebaseAuth.instance);
    
    // We use gemini-flash-latest per guidelines
    final model = googleAI.generativeModel(
      model: 'gemini-flash-latest',
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            "suggestions": Schema.array(
              description: "List of suggestions per exercise",
              items: Schema.object(
                properties: {
                  "exerciseName": Schema.string(description: "Name of the exercise"),
                  "suggestion": Schema.string(
                    description: "A short, actionable tip with weight/rep suggestion (max 2 sentences). Example: 'Tente 80kg x 12. Aumente as repetições já que houve falha no último treino.'"
                  ),
                },
                requiredProperties: ["exerciseName", "suggestion"],
              ),
            ),
          },
          requiredProperties: ["suggestions"],
        ),
      ),
    );

    // Build the prompt containing history for ONLY the planned exercises
    final buffer = StringBuffer();
    buffer.writeln("Você é um personal trainer especialista em hipertrofia e sobrecarga progressiva.");
    buffer.writeln("O usuário fará o seguinte treino hoje: ${plannedExercises.join(', ')}");
    buffer.writeln("Aqui está o histórico recente do usuário para esses exercícios:");
    
    bool hasHistory = false;
    for (var log in recentHistory) {
      for (var ex in log.exercises) {
        if (plannedExercises.contains(ex.name) && ex.completedSets > 0) {
          hasHistory = true;
          buffer.writeln("- ${log.date}: ${ex.name} -> ${ex.completedSets} séries de ${ex.reps} reps com ${ex.weight}kg. ${ex.notes.isNotEmpty ? 'Notas: ${ex.notes}' : ''}");
        }
      }
    }
    
    if (!hasHistory) {
      buffer.writeln("Nenhum histórico recente encontrado para esses exercícios. Forneça uma sugestão genérica para um treino de hipertrofia para cada um.");
    } else {
      buffer.writeln("Com base no histórico, forneça uma meta de carga e repetições para o treino de hoje usando os princípios de sobrecarga progressiva.");
    }

    try {
      final response = await model.generateContent([Content.text(buffer.toString())]);
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
      print("Erro ao gerar sugestão com IA: $e");
    }

    return {};
  }
}
