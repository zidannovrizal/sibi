import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Menata ulang frasa menggunakan GPT mini via API.
/// API key dibaca dari --dart-define atau env dengan nama `GPT5_API_KEY`.
class GptSentenceService {
  GptSentenceService._();
  static final GptSentenceService instance = GptSentenceService._();

  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-5-mini';

  String get _apiKey {
    final fromEnv = dotenv.env['GPT5_API_KEY'] ?? '';
    if (fromEnv.trim().isNotEmpty) return fromEnv.trim();
    return const String.fromEnvironment('GPT5_API_KEY', defaultValue: '').trim();
  }

  Future<String> rewrite(String phrase) async {
    final key = _apiKey.trim();
    if (key.isEmpty) return phrase; // fallback jika belum diset

    final prompt =
        'Susun ulang kata-kata berikut menjadi satu kalimat Bahasa Indonesia yang ringkas dan natural. '
        'Gunakan semua kata, jangan tambah kata baru, maksimal 1 kalimat pendek.\n'
        'Kata: "$phrase"\nKalimat:';

    try {
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 32,
          'temperature': 0.3,
        }),
      );

      if (resp.statusCode != 200) return phrase;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      final content = choices
              ?.first?['message']?['content']
              ?.toString()
              .trim() ??
          '';
      return content.isNotEmpty ? content : phrase;
    } catch (e) {
      debugPrint('GPT rewrite failed: $e');
      return phrase;
    }
  }
}
