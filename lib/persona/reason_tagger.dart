import 'dart:collection';

/// Lightweight NLP: map free text to a few canonical themes (on-device, no model weights).
class ReasonTagger {
  static const _lexicon = <String, List<String>>{
    'work': [
      'work',
      'job',
      'boss',
      'meeting',
      'office',
      'shift',
      'deadline',
      'overtime',
      'commute',
    ],
    'tired': [
      'tired',
      'sleep',
      'sleepy',
      'exhausted',
      'sick',
      'rest',
      'nap',
      'burnout',
    ],
    'social': [
      'friend',
      'party',
      'family',
      'date',
      'social',
      'dinner',
      'event',
    ],
    'focus': [
      'distracted',
      'phone',
      'scroll',
      'youtube',
      'games',
      'procrastinate',
    ],
    'health': [
      'hurt',
      'injury',
      'pain',
      'doctor',
      'recovery',
    ],
  };

  /// Tags found in [text], each at most once, stable priority order for ties.
  static List<String> tagsFromText(String text) {
    final t = text.toLowerCase();
    final found = LinkedHashMap<String, bool>();
    for (final e in _lexicon.entries) {
      for (final word in e.value) {
        if (t.contains(word)) {
          found[e.key] = true;
          break;
        }
      }
    }
    if (found.isEmpty) return const ['general'];
    return found.keys.toList();
  }

  static String dominantFromCounts(Map<String, int> counts) {
    if (counts.isEmpty) return 'general';
    const order = ['work', 'tired', 'focus', 'social', 'health', 'general'];
    var best = 'general';
    var bestScore = counts['general'] ?? 0;
    for (final k in order) {
      if (k == 'general') continue;
      final s = counts[k] ?? 0;
      if (s > bestScore) {
        bestScore = s;
        best = k;
      }
    }
    return best;
  }
}
