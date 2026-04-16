import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/commitment.dart';
import '../persona/nudge_synthesizer.dart';
import '../models/goal_item.dart';
import '../screens/check_in_screen.dart';
import 'commitment_storage.dart';
import 'storage_service.dart';

const _channelId = 'stayhard_reminders';
const _channelName = 'Stay Hard reminders';
const _channelDescription =
    'Nudges to stay on your goals without opening the app.';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _initialized = false;
String? _coldStartPayload;

GlobalKey<NavigatorState>? _navigatorKey;

class NotificationService {
  static void bindNavigator(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static Future<String?> takeColdStartPayload() async {
    final p = _coldStartPayload;
    _coldStartPayload = null;
    return p;
  }

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final localName = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: darwin);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final payload = launch!.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        _coldStartPayload = payload;
      }
    }

    await _ensureAndroidChannel();
    _initialized = true;
  }

  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (kDebugMode) {
      debugPrint('Notification response: $payload action=${response.actionId}');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openCheckInFromPayload(payload);
    });
  }

  /// Opens check-in when user taps a notification (foreground/background).
  static void openCheckInFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    var goalId = payload;
    var emphasizeMissed = false;
    if (payload.startsWith('followup|')) {
      final parts = payload.split('|');
      if (parts.length >= 2) goalId = parts[1];
      emphasizeMissed = true;
    } else if (payload.startsWith('goal|')) {
      final parts = payload.split('|');
      if (parts.length >= 2) goalId = parts[1];
    }

    final nav = _navigatorKey?.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => CheckInScreen(
          goalId: goalId,
          emphasizeMissedCommit: emphasizeMissed,
        ),
      ),
    );
  }

  static Future<void> _ensureAndroidChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(androidChannel);
  }

  static Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return true;
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static int dailyNotificationId(String goalId) =>
      _stableNotificationId('daily|$goalId');

  static int commitmentNotificationId(String goalId, String dateKey) =>
      _stableNotificationId('cmt|$goalId|$dateKey');

  static Future<void> cancelCommitmentReminder(
    String goalId,
    String dateKey,
  ) async {
    await _plugin.cancel(commitmentNotificationId(goalId, dateKey));
  }

  /// Daily at [hour]:[minute] local time, repeating; then same-day follow-ups.
  static Future<void> scheduleGoals(List<GoalItem> goals) async {
    await cancelAll();
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    for (final g in goals) {
      final id = dailyNotificationId(g.id);
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        g.hour,
        g.minute,
      );
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(g.reminderMessage),
        ),
        iOS: darwinDetails,
      );

      await _plugin.zonedSchedule(
        id,
        g.title,
        g.reminderMessage,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'goal|${g.id}',
      );
    }

    final commitments = await CommitmentStorage().loadAll();
    for (final c in commitments) {
      GoalItem? match;
      for (final x in goals) {
        if (x.id == c.goalId) {
          match = x;
          break;
        }
      }
      if (match != null) {
        await scheduleCommitmentReminder(c, match);
      }
    }
  }

  /// One-shot reminder at the time the user promised (same local day).
  static Future<void> scheduleCommitmentReminder(
    Commitment c,
    GoalItem g,
  ) async {
    final id = commitmentNotificationId(c.goalId, c.dateKey);
    await _plugin.cancel(id);

    final now = tz.TZDateTime.now(tz.local);
    final parts = c.dateKey.split('-');
    if (parts.length != 3) return;
    final y = int.tryParse(parts[0]);
    final mo = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || mo == null || d == null) return;

    var scheduled = tz.TZDateTime(
      tz.local,
      y,
      mo,
      d,
      c.hour,
      c.minute,
    );
    if (!scheduled.isAfter(now)) {
      return;
    }

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final body = await NudgeSynthesizer.followUpBody(
      goal: g,
      dateKey: c.dateKey,
      userDeferReason: c.reason,
    );
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: darwinDetails,
    );

    await _plugin.zonedSchedule(
      id,
      g.title,
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      payload: 'followup|${c.goalId}|${c.dateKey}',
    );
  }

  static int _stableNotificationId(String key) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    if (hash == 0) hash = 1;
    return hash;
  }

  static Future<void> rescheduleFromPrefs() async {
    final storage = StorageService();
    if (!await storage.isSetupComplete()) return;
    final goals = await storage.loadGoals();
    if (goals.isEmpty) return;
    await scheduleGoals(goals);
  }
}
