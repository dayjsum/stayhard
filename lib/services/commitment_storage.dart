import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/commitment.dart';
import '../util/date_keys.dart';

const _kCommitmentsJson = 'stayhard_commitments_json';

class CommitmentStorage {
  Future<List<Commitment>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCommitmentsJson);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Commitment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveAll(List<Commitment> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCommitmentsJson,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> upsert(Commitment c) async {
    final all = await loadAll();
    all.removeWhere((x) => x.goalId == c.goalId && x.dateKey == c.dateKey);
    all.add(c);
    await saveAll(all);
  }

  Future<void> remove(String goalId, String dateKey) async {
    final all = await loadAll();
    all.removeWhere((x) => x.goalId == goalId && x.dateKey == dateKey);
    await saveAll(all);
  }

  Future<Commitment?> forGoalOnDate(String goalId, String dateKey) async {
    final all = await loadAll();
    try {
      return all.firstWhere((x) => x.goalId == goalId && x.dateKey == dateKey);
    } catch (_) {
      return null;
    }
  }

  /// Drops commitments strictly before today's local date key.
  Future<void> pruneOlderThanToday(DateTime nowLocal) async {
    final today = dateKeyLocal(nowLocal);
    final all = await loadAll();
    final kept = all.where((c) => c.dateKey.compareTo(today) >= 0).toList();
    if (kept.length != all.length) {
      await saveAll(kept);
    }
  }
}
