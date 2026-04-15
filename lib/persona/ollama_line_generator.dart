import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/llm_config.dart';
import '../models/goal_item.dart';
import 'llm_bridge.dart';
import 'pattern_storage.dart';

/// Calls a local [Ollama](https://ollama.com) `/api/generate` endpoint.
///
/// Set `--dart-define=STAYHARD_LLM_BACKEND=ollama` and
/// `--dart-define=STAYHARD_LLM_URL=http://…:11434` (base URL, no path required).
class OllamaLineGenerator implements LineGenerator {
  const OllamaLineGenerator();

  @override
  Future<String> followUpLine({
    required GoalItem goal,
    required String dateKey,
    required String dominantTheme,
    required String memePackId,
  }) async {
    final base = LlmConfig.remoteUri;
    if (base == null) {
      throw StateError('STAYHARD_LLM_URL is not set for Ollama');
    }

    final uri = base.replace(
      path: '/api/generate',
      queryParameters: const {},
    );

    final profileRaw = await PatternStorage.instance.exportCompactForGoal(goal.id);
    final prompt = _buildPrompt(
      goalTitle: goal.title,
      dominantTheme: dominantTheme,
      memePackId: memePackId,
      dateKey: dateKey,
      profileJson: profileRaw,
    );

    final payload = <String, dynamic>{
      'model': LlmConfig.ollamaModel,
      'prompt': prompt,
      'stream': false,
      'options': <String, int>{
        'num_predict': LlmConfig.ollamaNumPredict.clamp(32, 256),
      },
    };

    final timeout = Duration(seconds: LlmConfig.timeoutSeconds.clamp(8, 120));
    final resp = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(timeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Ollama HTTP ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const FormatException('Ollama response must be a JSON object');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (map['error'] != null) {
      throw Exception('Ollama error: ${map['error']}');
    }
    final raw = map['response'];
    if (raw is! String || raw.trim().isEmpty) {
      throw const FormatException('Ollama response missing "response" string');
    }
    var line = raw.trim();
    // Strip common wrapping quotes new models add.
    if (line.length >= 2 &&
        ((line.startsWith('"') && line.endsWith('"')) ||
            (line.startsWith("'") && line.endsWith("'")))) {
      line = line.substring(1, line.length - 1).trim();
    }
    if (line.length > 500) {
      line = line.substring(0, 500);
    }
    if (kDebugMode) {
      debugPrint('StayHard Ollama line (${line.length} chars)');
    }
    return line;
  }

  String _buildPrompt({
    required String goalTitle,
    required String dominantTheme,
    required String memePackId,
    required String dateKey,
    required String profileJson,
  }) {
    return '''
You are StayHard: a direct, respectful accountability voice (no slurs, no body-shaming, no hate).

Task: Write EXACTLY one or two short sentences nudging the user to execute their goal NOW. No bullet points. No roleplay preamble. Max 280 characters in total.

Context (JSON): goal title "$goalTitle", slip pattern theme "$dominantTheme", voice pack "$memePackId", local day "$dateKey", learned profile (themes only): $profileJson

Answer with only the sentence(s), nothing else.''';
  }
}
