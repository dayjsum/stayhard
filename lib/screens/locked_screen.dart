import 'package:flutter/material.dart';

import '../models/goal_item.dart';
import '../persona/pattern_storage.dart';
import '../services/storage_service.dart';
import 'check_in_screen.dart';

class LockedScreen extends StatefulWidget {
  const LockedScreen({super.key});

  @override
  State<LockedScreen> createState() => _LockedScreenState();
}

class _LockedScreenState extends State<LockedScreen> {
  final _storage = StorageService();
  late Future<List<GoalItem>> _goalsFuture;

  @override
  void initState() {
    super.initState();
    _goalsFuture = _storage.loadGoals();
  }

  Future<void> _changeVoice() async {
    final current = await PatternStorage.instance.getMemePackId();
    if (!mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Reminder voice'),
          children: [
            RadioListTile<String>(
              title: const Text('Auto — rotates daily'),
              value: kPackAuto,
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<String>(
              title: const Text('Straight talk'),
              value: kPackClassic,
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<String>(
              title: const Text('Emoji / compact'),
              value: kPackEmoji,
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<String>(
              title: const Text('Grinder refs'),
              value: kPackGrinder,
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
          ],
        );
      },
    );
    if (picked != null) {
      await PatternStorage.instance.setMemePackId(picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice updated for next follow-ups.')),
        );
      }
    }
  }

  Future<void> _openGoalPicker() async {
    final goals = await _goalsFuture;
    if (!mounted) return;
    if (goals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No goals on file.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Pick a goal to check in',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              for (final g in goals)
                ListTile(
                  title: Text(g.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CheckInScreen(goalId: g.id),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Text(
                'STAY HARD',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  letterSpacing: 4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'You are locked in.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your reminders fire from the system notification shade — '
                'not from inside this app. That is the point: stay off the screen, '
                'stay on the work. Tap a reminder to answer yes / not yet.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.45,
                  color: theme.colorScheme.onSurface.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Lightweight on your phone: no account, no server for reminders — '
                'schedules and habits stay on-device and use the same notifications '
                'you already use for everything else.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.4,
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _openGoalPicker,
                child: const Text('Check in on a goal'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _changeVoice,
                child: const Text('Change reminder voice / meme layer'),
              ),
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'To change goals later, clear this app\'s storage in Android '
                    'settings (or delete and reinstall the app). There is no edit '
                    'screen by design.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ),
              const Spacer(flex: 3),
              Text(
                'Close the app. Do the reps.',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
