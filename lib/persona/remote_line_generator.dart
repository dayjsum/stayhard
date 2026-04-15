import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/llm_config.dart';
import '../models/goal_item.dart';
import 'llm_bridge.dart';
import 'pattern_storage.dart';

/// POSTs a **small JSON** contract to [LlmConfig.remoteUri]; your server calls the LLM.
///
/// ### Request body (`stayhard.line_request.v1`)
/// ```json
/// {
///   "schema": "stayhard.line_request.v1",
///   "goalId": "...",
///   "goalTitle": "Gym",
///   "dominantTheme": "work",
///   "memePackId": "emoji",
///   "dateKey": "2026-04-15",
///   "profile": { "g": "...", "t": {"work": 3}, "d": "work" }
/// }
/// ```
///
/// ### Response
/// ```json
/// { "line": "One short accountability sentence." }
/// ```
/// Also accepts keys `message` or `text` for the line string.
class RemoteLineGenerator implements LineGenerator {
  const RemoteLineGenerator();

  @override
  Future<String> followUpLine({
    required GoalItem goal,
    required String dateKey,
    required String dominantTheme,
    required String memePackId,
  }) async {
    final uri = LlmConfig.remoteUri;
    if (uri == null) {
      throw StateError('STAYHARD_LLM_URL is not set or invalid');
    }

    final profileRaw = await PatternStorage.instance.exportCompactForGoal(goal.id);
    final profile = jsonDecode(profileRaw);

    final payload = <String, dynamic>{
      'schema': 'stayhard.line_request.v1',
      'goalId': goal.id,
      'goalTitle': goal.title,
      'dominantTheme': dominantTheme,
      'memePackId': memePackId,
      'dateKey': dateKey,
      'profile': profile,
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = LlmConfig.bearerToken.trim();
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final timeout = Duration(seconds: LlmConfig.timeoutSeconds.clamp(4, 60));
    final resp = await http
        .post(uri, headers: headers, body: jsonEncode(payload))
        .timeout(timeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('LLM proxy HTTP ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const FormatException('LLM response must be a JSON object');
    }
    final map = Map<String, dynamic>.from(decoded);
    final raw = map['line'] ?? map['message'] ?? map['text'];
    if (raw is! String || raw.trim().isEmpty) {
      throw const FormatException('LLM response missing line/message/text');
    }
    var line = raw.trim();
    if (line.length > 500) {
      line = line.substring(0, 500);
    }
    if (kDebugMode) {
      debugPrint('StayHard remote line (${line.length} chars)');
    }
    return line;
  }
}
