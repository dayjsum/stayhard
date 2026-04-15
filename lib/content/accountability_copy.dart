import '../models/goal_item.dart';

/// Check-in prompts (follow-up lines live in `persona/` packs + synthesizer).
class AccountabilityCopy {
  static String whyNotPrompt(GoalItem goal) =>
      'What pulled you away from ${goal.title}? (optional)';

  static String reschedulePrompt(GoalItem goal) =>
      'When will you actually do ${goal.title} today?';
}
