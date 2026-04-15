import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'services/notification_service.dart';

const _kUniqueName = 'stayhard-reschedule';
const _kTaskName = 'stayhardReschedule';

@pragma('vm:entry-point')
void stayhardWorkmanagerCallback() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task != _kTaskName) {
      return Future.value(false);
    }
    await NotificationService.init();
    await NotificationService.rescheduleFromPrefs();
    return Future.value(true);
  });
}

Future<void> registerPeriodicReschedule() async {
  if (kIsWeb) return;
  if (!Platform.isAndroid) return;
  await Workmanager().initialize(
    stayhardWorkmanagerCallback,
    isInDebugMode: kDebugMode,
  );
  await Workmanager().registerPeriodicTask(
    _kUniqueName,
    _kTaskName,
    // Daily is enough to re-apply schedules after reboot — fewer wakeups than hourly.
    frequency: const Duration(hours: 24),
    constraints: Constraints(
      networkType: NetworkType.not_required,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}
