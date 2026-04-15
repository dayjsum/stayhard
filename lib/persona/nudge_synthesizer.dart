import 'package:flutter/foundation.dart';

import '../config/llm_config.dart';
import '../models/goal_item.dart';
import 'llm_bridge.dart';
import 'ollama_line_generator.dart';
import 'pattern_storage.dart';
import 'remote_line_generator.dart';

/// Follow-up lines: **Ollama** (local), **generic HTTP** proxy, or **local** packs.
///
/// Override with [bindGenerator] in tests.
class NudgeSynthesizer {
  NudgeSynthesizer._();

  static LineGenerator? _bound;

  /// Tests only — pass `null` to restore default behavior.
  static void bindGenerator(LineGenerator? g) => _bound = g;

  static Future<String> followUpBody({
    required GoalItem goal,
    required String dateKey,
  }) async {
    final pack = await PatternStorage.instance.getEffectiveMemePackId();
    final profile = await PatternStorage.instance.profileForGoal(goal.id);

    final bound = _bound;
    if (bound != null) {
      return bound.followUpLine(
        goal: goal,
        dateKey: dateKey,
        dominantTheme: profile.dominantTheme,
        memePackId: pack,
      );
    }

    if (LlmConfig.useOllama) {
      try {
        return await const OllamaLineGenerator().followUpLine(
          goal: goal,
          dateKey: dateKey,
          dominantTheme: profile.dominantTheme,
          memePackId: pack,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('StayHard Ollama failed → local fallback: $e');
        }
      }
    } else if (LlmConfig.useGenericHttp) {
      try {
        return await const RemoteLineGenerator().followUpLine(
          goal: goal,
          dateKey: dateKey,
          dominantTheme: profile.dominantTheme,
          memePackId: pack,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('StayHard LLM remote failed → local fallback: $e');
        }
      }
    }

    return const LocalHeuristicGenerator().followUpLine(
      goal: goal,
      dateKey: dateKey,
      dominantTheme: profile.dominantTheme,
      memePackId: pack,
    );
  }
}
