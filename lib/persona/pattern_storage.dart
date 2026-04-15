import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pattern_profile.dart';
import 'reason_tagger.dart';

const _kProfilesJson = 'stayhard_pattern_profiles_v1';
const _kMemePack = 'stayhard_meme_pack_v1';

/// Default voice pack id (classic accountability lines).
const String kPackClassic = 'classic';
const String kPackEmoji = 'emoji';
const String kPackGrinder = 'grinder';

/// Rotates effective pack by calendar day so the vibe shifts without user micromanaging.
const String kPackAuto = 'auto';

const List<String> kAllPackIds = [
  kPackClassic,
  kPackEmoji,
  kPackGrinder,
  kPackAuto,
];

const List<String> kRotatingPacks = [kPackClassic, kPackEmoji, kPackGrinder];

class PatternStorage {
  PatternStorage._();
  static final PatternStorage instance = PatternStorage._();

  Future<Map<String, GoalPatternProfile>> loadAllProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProfilesJson);
    if (raw == null || raw.isEmpty) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final out = <String, GoalPatternProfile>{};
    for (final e in map.entries) {
      out[e.key] = GoalPatternProfile.fromJson(
        Map<String, dynamic>.from(e.value as Map),
      );
    }
    return out;
  }

  Future<void> saveProfiles(Map<String, GoalPatternProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      profiles.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_kProfilesJson, encoded);
  }

  Future<GoalPatternProfile> profileForGoal(String goalId) async {
    final all = await loadAllProfiles();
    return all[goalId] ??
        GoalPatternProfile(goalId: goalId, themeCounts: const {'general': 0});
  }

  /// Bump theme counters from a free-text defer reason (on-device only).
  Future<void> recordDeferReason(String goalId, String reason) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) return;
    final tags = ReasonTagger.tagsFromText(trimmed);
    final all = await loadAllProfiles();
    final existing = all[goalId] ??
        GoalPatternProfile(goalId: goalId, themeCounts: const {'general': 0});
    final merged = existing.incrementThemes(tags);
    all[goalId] = merged;
    await saveProfiles(all);
  }

  Future<String> getMemePackId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kMemePack) ?? kPackClassic;
  }

  /// Resolved pack for copy generation (`auto` → daily rotation).
  Future<String> getEffectiveMemePackId() async {
    final raw = await getMemePackId();
    if (raw == kPackAuto) {
      final day = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
      return kRotatingPacks[day % kRotatingPacks.length];
    }
    return raw;
  }

  Future<void> setMemePackId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (!kAllPackIds.contains(id)) return;
    await prefs.setString(_kMemePack, id);
  }

  /// Tiny export for a future LLM: one map per goal, themes only.
  Future<String> exportCompactForRemote() async {
    final all = await loadAllProfiles();
    final list = all.values.map((p) => p.toCompactJson()).toList();
    return jsonEncode(list);
  }

  /// Single-goal profile JSON (smaller than [exportCompactForRemote] for line calls).
  Future<String> exportCompactForGoal(String goalId) async {
    final p = await profileForGoal(goalId);
    return jsonEncode(p.toCompactJson());
  }
}
