import 'package:flutter/foundation.dart';

import '../config/llm_config.dart';
import '../models/goal_item.dart';
import 'llm_bridge.dart';
import 'pattern_storage.dart';
import 'remote_line_generator.dart';

/// Follow-up lines: **your API** (cache + LLM server-side) or **local** fallback.
///
/// The app never runs an LLM. [bindGenerator] is for tests only.
class NudgeSynthesizer {
  NudgeSynthesizer._();

  static LineGenerator? _bound;

  /// Tests only — pass `null` to restore default behavior.
  static void bindGenerator(LineGenerator? g) => _bound = g;

  /// [userDeferReason] is forwarded for your cache key when the user typed “not yet”.
  static Future<String> followUpBody({
    required GoalItem goal,
    required String dateKey,
    String? userDeferReason,
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
        userDeferReason: userDeferReason,
      );
    }

    if (LlmConfig.isRemoteConfigured) {
      try {
        return await const RemoteLineGenerator().followUpLine(
          goal: goal,
          dateKey: dateKey,
          dominantTheme: profile.dominantTheme,
          memePackId: pack,
          userDeferReason: userDeferReason,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('StayHard API line failed → local fallback: $e');
        }
      }
    }

    return const LocalHeuristicGenerator().followUpLine(
      goal: goal,
      dateKey: dateKey,
      dominantTheme: profile.dominantTheme,
      memePackId: pack,
      userDeferReason: userDeferReason,
    );
  }
}
