import 'package:flutter/material.dart';

import 'screens/locked_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/commitment_storage.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'workmanager_setup.dart';

final GlobalKey<NavigatorState> stayHardNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await CommitmentStorage().pruneOlderThanToday(DateTime.now());
  final storage = StorageService();
  if (await storage.isSetupComplete()) {
    await registerPeriodicReschedule();
  }
  final coldPayload = await NotificationService.takeColdStartPayload();
  runApp(StayHardApp(coldStartNotificationPayload: coldPayload));
}

class StayHardApp extends StatefulWidget {
  const StayHardApp({super.key, this.coldStartNotificationPayload});

  final String? coldStartNotificationPayload;

  @override
  State<StayHardApp> createState() => _StayHardAppState();
}

class _StayHardAppState extends State<StayHardApp> {
  final _storage = StorageService();
  late Future<bool> _setupFuture;
  bool _handledColdStart = false;

  @override
  void initState() {
    super.initState();
    NotificationService.bindNavigator(stayHardNavigatorKey);
    _setupFuture = _storage.isSetupComplete();
  }

  void _reloadLocked() {
    setState(() {
      _setupFuture = Future.value(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: stayHardNavigatorKey,
      title: 'Stay Hard',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: FutureBuilder<bool>(
        future: _setupFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final locked = snapshot.data ?? false;
          if (locked) {
            final cold = widget.coldStartNotificationPayload;
            if (!_handledColdStart &&
                cold != null &&
                cold.isNotEmpty) {
              _handledColdStart = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                NotificationService.openCheckInFromPayload(cold);
              });
            }
            return const LockedScreen();
          }
          return OnboardingScreen(onLocked: _reloadLocked);
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    const seed = Color(0xFFC62828);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF0E0E0E),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest.withOpacity(0.35),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
