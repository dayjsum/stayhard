import '../models/goal_item.dart';
import 'meme_packs.dart';

/// Swap implementations later (e.g. HTTP LLM) while keeping the same call site.
/// Remote prompts should stay **tiny**: export `PatternStorage.exportCompactForRemote()`
/// (themes + goal ids) instead of full chat logs to save tokens.
abstract class LineGenerator {
  Future<String> followUpLine({
    required GoalItem goal,
    required String dateKey,
    required String dominantTheme,
    required String memePackId,
  });
}

/// On-device: no model weights, no network, no token spend.
class LocalHeuristicGenerator implements LineGenerator {
  const LocalHeuristicGenerator();

  @override
  Future<String> followUpLine({
    required GoalItem goal,
    required String dateKey,
    required String dominantTheme,
    required String memePackId,
  }) async {
    final salt = dateKey.hashCode ^ memePackId.hashCode ^ goal.id.hashCode;
    return MemePacks.lineFor(
      title: goal.title,
      packId: memePackId,
      dominantTheme: dominantTheme,
      salt: salt,
    );
  }
}
