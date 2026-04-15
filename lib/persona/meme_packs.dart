/// Rotating "voice" layers for nudges. Swap packs over time (or ship OTA JSON later)
/// without shipping a full LLM. Copy stays direct — no harassment, no slurs.
class MemePacks {
  MemePacks._();

  static String lineFor({
    required String title,
    required String packId,
    required String dominantTheme,
    required int salt,
  }) {
    final bucket = _bucketForTheme(dominantTheme);
    final lines = _lines(packId, bucket);
    if (lines.isEmpty) {
      return _hardDefault(title, salt);
    }
    return lines[salt.abs() % lines.length].replaceAll('{title}', title);
  }

  /// Theme-aware routing: same meme pack can lean slightly on what we learned.
  static String _bucketForTheme(String dominant) {
    switch (dominant) {
      case 'work':
        return 'work';
      case 'tired':
        return 'tired';
      case 'focus':
        return 'focus';
      case 'social':
        return 'social';
      case 'health':
        return 'health';
      default:
        return 'general';
    }
  }

  static List<String> _lines(String packId, String bucket) {
    switch (packId) {
      case 'emoji':
        return _emoji(bucket);
      case 'grinder':
        return _grinder(bucket);
      case 'classic':
      default:
        return _classic(bucket);
    }
  }

  static List<String> _classic(String bucket) {
    const core = <String>[
      'You named a time for {title}. The clock did not lie—go do it.',
      'This was the window you chose for {title}. Honor it.',
      '{title}: you pushed the time once. Do not negotiate with yourself twice.',
      'No more drift. {title} was due—execute now or reset tomorrow honestly.',
      'You said you would handle {title}. Prove it to yourself in the next hour.',
    ];
    if (bucket == 'work') {
      return [
        ...core,
        'Meetings ended. {title} did not—go clock the win.',
        'Inbox zero is fake glory. {title} is the real scoreboard today.',
      ];
    }
    if (bucket == 'tired') {
      return [
        ...core,
        'Low energy is a signal, not a sentence. Do the smallest real rep on {title}.',
        'Tired is loud. Commitment is louder—one block on {title}, now.',
      ];
    }
    if (bucket == 'focus') {
      return [
        ...core,
        'The feed can wait. {title} cannot—close the loop you promised.',
      ];
    }
    return core;
  }

  static List<String> _emoji(String bucket) {
    final base = <String>[
      '📉 excuses / 📈 {title}. pick one for the next 45.',
      '⏰ said a time. 🧱 {title} is still sitting there. go.',
      '🎧 mute the noise. 🏃 {title} is the main character today.',
      '🔒 you locked a window for {title}. 🔓 unlock it with action.',
    ];
    if (bucket == 'work') {
      return [
        ...base,
        '📅 calendar ate you? cool. 🥊 {title} still needs one round.',
      ];
    }
    if (bucket == 'tired') {
      return [
        ...base,
        '🪫 low battery? ok. 🔌 {title} can be a 10-minute charge.',
      ];
    }
    return base;
  }

  /// "Grinder" = intensity + cultural references (motivational, not insulting).
  static List<String> _grinder(String bucket) {
    final base = <String>[
      'Who carries the hard part today? You—{title} is waiting on you.',
      'Same storm, different sailor: {title} still needs steering.',
      'Boats, logs, code, iron—pick your metaphor. {title} is the set you skip when it counts.',
      'You moved the time once for {title}. The world did not get softer—get after it.',
      'Discipline is boring until {title} is done. Then it feels like power.',
    ];
    if (bucket == 'work') {
      return [
        ...base,
        'Work stole the morning—fine. Steal the evening back with {title}.',
      ];
    }
    if (bucket == 'focus') {
      return [
        ...base,
        'Scroll culture is optional. {title} is mandatory if you meant what you typed.',
      ];
    }
    return base;
  }

  static String _hardDefault(String title, int salt) {
    const fallbacks = <String>[
      'Time you picked for {title}. Show up.',
      '{title}: execute the block you promised.',
    ];
    return fallbacks[salt.abs() % fallbacks.length].replaceAll('{title}', title);
  }
}
