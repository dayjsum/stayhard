import 'reason_tagger.dart';

/// Compact habit profile for one goal — safe to send to a future API as a tiny JSON blob.
class GoalPatternProfile {
  GoalPatternProfile({
    required this.goalId,
    required Map<String, int> themeCounts,
    this.lastUpdatedMs,
  }) : themeCounts = Map<String, int>.from(themeCounts);

  final String goalId;
  final Map<String, int> themeCounts;
  final int? lastUpdatedMs;

  String get dominantTheme => ReasonTagger.dominantFromCounts(themeCounts);

  /// Minimal payload if you later call a remote LLM (themes only → fewer tokens).
  Map<String, dynamic> toCompactJson() => {
        'g': goalId,
        't': themeCounts,
        'd': dominantTheme,
      };

  Map<String, dynamic> toJson() => {
        'goalId': goalId,
        'themeCounts': themeCounts,
        if (lastUpdatedMs != null) 'lastUpdatedMs': lastUpdatedMs,
      };

  factory GoalPatternProfile.fromJson(Map<String, dynamic> json) {
    final raw = json['themeCounts'];
    final counts = <String, int>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final v = e.value;
        if (v is int) counts[e.key.toString()] = v;
      }
    }
    return GoalPatternProfile(
      goalId: json['goalId'] as String,
      themeCounts: counts,
      lastUpdatedMs: json['lastUpdatedMs'] as int?,
    );
  }

  GoalPatternProfile incrementThemes(Iterable<String> tags) {
    final next = Map<String, int>.from(themeCounts);
    for (final tag in tags) {
      next[tag] = (next[tag] ?? 0) + 1;
    }
    next['general'] = (next['general'] ?? 0); // ensure key exists for tie-break
    return GoalPatternProfile(
      goalId: goalId,
      themeCounts: next,
      lastUpdatedMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
