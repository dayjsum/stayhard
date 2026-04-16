import '../models/goal_item.dart';
import 'meme_packs.dart';

/// Pluggable line source. Production uses [RemoteLineGenerator] → **your API** only.
abstract class LineGenerator {
  Future<String> followUpLine({
    required GoalItem goal,
    required String dateKey,
    required String dominantTheme,
    required String memePackId,
    /// Same-day defer reason when user typed "not yet" — used for server cache key.
    String? userDeferReason,
  });
}

/// On-device fallback: no network, no tokens.
class LocalHeuristicGenerator implements LineGenerator {
  const LocalHeuristicGenerator();

  @override
  Future<String> followUpLine({
    required GoalItem goal,
    required String dateKey,
    required String dominantTheme,
    required String memePackId,
    String? userDeferReason,
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
