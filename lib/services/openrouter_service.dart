import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenRouterService {
  static const _endpoint = 'https://openrouter.ai/api/v1/chat/completions';

  final String apiKey;
  OpenRouterService(this.apiKey);

  Future<String> generateRecipe(List<String> items) async {
    final prompt = "Generate a creative recipe using only these ingredients: ${items.join(', ')}. "
        "Provide a name, ingredients list, and simple cooking steps.";

    final res = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'openrouter/auto',
        'messages': [
          {'role': 'system', 'content': 'You are an expert chef helping people cook from what’s in their kitchen.'},
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.7,
        'max_tokens': 600,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception("OpenRouter error: ${res.body}");
    }
  }
}
