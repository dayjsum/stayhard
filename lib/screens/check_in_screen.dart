import 'package:flutter/material.dart';

import '../content/accountability_copy.dart';
import '../models/commitment.dart';
import '../models/goal_item.dart';
import '../persona/pattern_storage.dart';
import '../services/commitment_storage.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../util/date_keys.dart';

/// Short accountability flow for one goal. Not medical advice; voluntary habit data only.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({
    super.key,
    required this.goalId,
    this.emphasizeMissedCommit = false,
  });

  final String goalId;
  final bool emphasizeMissedCommit;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _storage = StorageService();
  final _commitments = CommitmentStorage();
  final _reasonController = TextEditingController();

  GoalItem? _goal;
  bool _loading = true;
  int _step = 0;
  late TimeOfDay _deferTime;

  @override
  void initState() {
    super.initState();
    _deferTime = const TimeOfDay(hour: 17, minute: 0);
    _load();
  }

  Future<void> _load() async {
    final goals = await _storage.loadGoals();
    GoalItem? found;
    for (final g in goals) {
      if (g.id == widget.goalId) {
        found = g;
        break;
      }
    }
    if (found != null) {
      final wd = DateTime.now().weekday;
      final learned = found.learnedCommitByWeekday[wd];
      if (learned != null) {
        _deferTime = TimeOfDay(hour: learned.hour, minute: learned.minute);
      }
    }
    if (!mounted) return;
    setState(() {
      _goal = found;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _question(GoalItem g) {
    final q = g.checkInQuestion?.trim();
    if (q != null && q.isNotEmpty) return q;
    return 'Did you make progress on "${g.title}" today?';
  }

  Future<void> _onYes() async {
    final g = _goal;
    if (g == null) return;
    final today = dateKeyLocal(DateTime.now());
    await _commitments.remove(g.id, today);
    await NotificationService.cancelCommitmentReminder(g.id, today);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged: ${g.title} done. Keep the streak.')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _submitDefer() async {
    final g = _goal;
    if (g == null) return;
    final today = dateKeyLocal(DateTime.now());
    final now = DateTime.now();
    final commitAt = DateTime(
      now.year,
      now.month,
      now.day,
      _deferTime.hour,
      _deferTime.minute,
    );
    if (!commitAt.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick a time later today so we can hold you to it.'),
        ),
      );
      return;
    }

    final reason = _reasonController.text.trim();
    await PatternStorage.instance.recordDeferReason(g.id, reason);

    final c = Commitment(
      goalId: g.id,
      dateKey: today,
      hour: _deferTime.hour,
      minute: _deferTime.minute,
      reason: reason.isEmpty ? null : reason,
    );

    final wd = now.weekday;
    final updated = g.withLearnedCommit(wd, _deferTime.hour, _deferTime.minute);
    final all = await _storage.loadGoals();
    final next = all.map((x) => x.id == g.id ? updated : x).toList();
    await _storage.saveGoals(next);
    await _commitments.upsert(c);
    await NotificationService.scheduleCommitmentReminder(c, updated);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Noted. We will ping you at ${_deferTime.format(context)} for ${g.title}.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final g = _goal;
    if (g == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Check-in')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('That goal was not found. Storage may have been cleared.'),
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(g.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Habit check-in only. This is not medical advice, not a diagnosis, '
            'and not a HIPAA-covered service — just voluntary goals you typed.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          if (widget.emphasizeMissedCommit)
            Card(
              color: theme.colorScheme.errorContainer.withOpacity(0.35),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'You set a time for ${g.title}. If you have not done it yet, '
                  'either go now or reset honestly below.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ),
            ),
          if (widget.emphasizeMissedCommit) const SizedBox(height: 16),
          Text(
            _question(g),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 20),
          if (_step == 0) ...[
            FilledButton(
              onPressed: _onYes,
              child: const Text('Yes — done today'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Not yet'),
            ),
          ] else ...[
            Text(
              AccountabilityCopy.whyNotPrompt(g),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Work ran late, felt tired, etc.',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AccountabilityCopy.reschedulePrompt(g),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_deferTime.format(context)),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _deferTime,
                );
                if (picked != null) {
                  setState(() => _deferTime = picked);
                }
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitDefer,
              child: const Text('Save time & hold me to it'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('Back'),
            ),
          ],
        ],
      ),
    );
  }
}
