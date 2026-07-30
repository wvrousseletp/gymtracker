import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

void main() async {
  final apiKey = utf8.decode(base64.decode('QVEuQWI4Uk42SmJIcjN3MUIySG0tOElyakJ4SGttZnRtVVFCUmI2V3hwYlQxOHFVeUd1OFE='));
  final model = GenerativeModel(
    model: 'gemini-flash-latest',
    apiKey: apiKey,
    generationConfig: GenerationConfig(
      temperature: 0.4,
      maxOutputTokens: 500,
    ),
  );

  try {
    final response = await model.generateContent([
      Content.text("Você é um treinador de elite especialista em musculação e biomecânica.\nEstou analisando meu histórico do exercício: Rosca Alternada com Halteres.\nAqui estão as minhas sessões de treino passadas em ordem decrescente (da mais recente para a mais antiga):\n- 2026-07-29: 3 séries. Peso máximo do dia: 14kg. Reps: 10. RPE: 8. Falha relatada: Não.\n- 2026-07-26: 3 séries. Peso máximo do dia: 14kg. Reps: 10. RPE: 8. Falha relatada: Não.\n\nFaça uma análise profunda, direta e motivadora.\nIdentifique tendências (estagnação, progressão de volume ou carga) e me dê uma dica prática e acionável para o meu próximo treino desse exercício. Não use Markdown exagerado, apenas texto limpo.")
    ]);
    print("OUTPUT:");
    print(response.text);
  } catch (e) {
    print("ERROR: $e");
  }
}
