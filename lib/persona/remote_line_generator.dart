import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/llm_config.dart';
import '../models/goal_item.dart';
import 'llm_bridge.dart';
import 'pattern_storage.dart';

/// POSTs to **your** HTTPS API. The app does not run an LLM.
///
/// ## Server contract (`stayhard.line_request.v2`)
///
/// Your backend should:
/// 1. Build a **cache key** from normalized `userDeferReason` when non-empty,
///    else from `deterministicFallbackKey` (stable id for “no free text” rows).
/// 2. If a row exists for that key (+ goal / kind scope) → return stored `line`
///    (optionally set `cached: true`).
/// 3. If miss → call your LLM once → **persist** `(cache_key, request_snapshot, line)`
///    → return `line` (`cached: false`).
/// 4. Apply **rate limits** and auth so spam cannot burn tokens.
///
/// ### Request JSON
/// ```json
/// {
///   "schema": "stayhard.line_request.v2",
///   "kind": "followup_commitment",
///   "goalId": "...",
///   "goalTitle": "Gym",
///   "dominantTheme": "work",
///   "memePackId": "emoji",
///   "dateKey": "2026-04-15",
///   "profile": { "g": "...", "t": {"work": 3}, "d": "work" },
///   "userDeferReason": "meeting ran late",
///   "deterministicFallbackKey": "stayhard/followup/v1/<goalId>/<dateKey>/<theme>/<pack>"
/// }
/// ```
///
/// ### Response JSON
/// ```json
/// { "line": "…", "cached": true }
/// ```
/// `line` required; `cached` optional (for your analytics). Also accepts `message` / `text`.
class RemoteLineGenerator implements LineGenerator {
  const RemoteLineGenerator();

  static String _fallbackKey(
    String goalId,
    String dateKey,
    String dominantTheme,
    String memePackId,
  ) =>
      'stayhard/followup/v1/$goalId/$dateKey/$dominantTheme/$memePackId';

  @override
  Future<String> followUpLine({
    required GoalItem goal,
    required String dateKey,
    required String dominantTheme,
    required String memePackId,
    String? userDeferReason,
  }) async {
    final uri = LlmConfig.remoteUri;
    if (uri == null) {
      throw StateError('STAYHARD_LLM_URL is not set or invalid');
    }

    final profileRaw = await PatternStorage.instance.exportCompactForGoal(goal.id);
    final profile = jsonDecode(profileRaw);
    final trimmedReason = userDeferReason?.trim();
    final hasReason = trimmedReason != null && trimmedReason.isNotEmpty;

    final payload = <String, dynamic>{
      'schema': 'stayhard.line_request.v2',
      'kind': 'followup_commitment',
      'goalId': goal.id,
      'goalTitle': goal.title,
      'dominantTheme': dominantTheme,
      'memePackId': memePackId,
      'dateKey': dateKey,
      'profile': profile,
      if (hasReason) 'userDeferReason': trimmedReason,
      'deterministicFallbackKey': _fallbackKey(
        goal.id,
        dateKey,
        dominantTheme,
        memePackId,
      ),
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
      throw Exception('LLM API HTTP ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const FormatException('LLM API response must be a JSON object');
    }
    final map = Map<String, dynamic>.from(decoded);
    final raw = map['line'] ?? map['message'] ?? map['text'];
    if (raw is! String || raw.trim().isEmpty) {
      throw const FormatException('LLM API response missing line/message/text');
    }
    var line = raw.trim();
    if (line.length > 500) {
      line = line.substring(0, 500);
    }
    if (kDebugMode) {
      final hit = map['cached'];
      debugPrint(
        'StayHard API line (${line.length} chars) cached=${hit is bool ? hit : '?'}',
      );
    }
    return line;
  }
}
