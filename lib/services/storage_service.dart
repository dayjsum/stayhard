import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/goal_item.dart';

const _kSetupComplete = 'stayhard_setup_complete';
const _kGoalsJson = 'stayhard_goals_json';

class StorageService {
  Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSetupComplete) ?? false;
  }

  Future<void> markSetupComplete(List<GoalItem> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kGoalsJson,
      jsonEncode(goals.map((g) => g.toJson()).toList()),
    );
    await prefs.setBool(_kSetupComplete, true);
  }

  Future<List<GoalItem>> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kGoalsJson);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => GoalItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveGoals(List<GoalItem> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kGoalsJson,
      jsonEncode(goals.map((g) => g.toJson()).toList()),
    );
  }
}
