import 'dart:math';

import 'package:flutter/material.dart';

import '../models/goal_item.dart';
import '../persona/pattern_storage.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../workmanager_setup.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onLocked});

  final VoidCallback onLocked;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _storage = StorageService();
  final _scroll = ScrollController();
  bool _busy = false;
  String _voicePackId = kPackAuto;

  late List<_GoalDraft> _drafts;

  @override
  void initState() {
    super.initState();
    _drafts = [
      _GoalDraft(
        id: _newId(),
        title: 'LeetCode',
        message: 'Time for focused reps. Open your editor, not social feeds.',
        checkInQuestion: 'Did you get a LeetCode session in yet?',
        hour: 9,
        minute: 0,
      ),
      _GoalDraft(
        id: _newId(),
        title: 'Gym',
        message: 'Did you train today? If not, the iron is waiting.',
        checkInQuestion: 'Did you go to the gym yet?',
        hour: 18,
        minute: 30,
      ),
    ];
  }

  String _newId() {
    final r = Random().nextInt(1 << 20);
    return '${DateTime.now().microsecondsSinceEpoch}_$r';
  }

  Future<void> _pickTime(int index) async {
    final d = _drafts[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: d.hour, minute: d.minute),
    );
    if (picked == null) return;
    setState(() {
      d.hour = picked.hour;
      d.minute = picked.minute;
    });
  }

  void _addGoal() {
    setState(() {
      _drafts.add(
        _GoalDraft(
          id: _newId(),
          title: '',
          message: '',
          checkInQuestion: '',
          hour: 12,
          minute: 0,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeGoal(int index) {
    if (_drafts.length <= 1) return;
    setState(() => _drafts.removeAt(index));
  }

  Future<void> _lockIn() async {
    final goals = <GoalItem>[];
    for (final d in _drafts) {
      final title = d.titleController.text.trim();
      final message = d.messageController.text.trim();
      final checkIn = d.checkInQuestionController.text.trim();
      if (title.isEmpty || message.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Each goal needs a title and a reminder message.'),
          ),
        );
        return;
      }
      goals.add(
        GoalItem(
          id: d.id,
          title: title,
          reminderMessage: message,
          hour: d.hour,
          minute: d.minute,
          checkInQuestion: checkIn.isEmpty ? null : checkIn,
        ),
      );
    }

    setState(() => _busy = true);
    try {
      await NotificationService.requestPermissions();
      await PatternStorage.instance.setMemePackId(_voicePackId);
      await _storage.markSetupComplete(goals);
      await NotificationService.scheduleGoals(goals);
      await registerPeriodicReschedule();
      if (!mounted) return;
      widget.onLocked();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not finish setup: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('One-time setup'),
        centerTitle: true,
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Set the goals you want the world to hold you to. After you lock in, '
            'this app mostly stays closed — daily nudges and check-ins open from '
            'notifications when you tap them. No sign-in: goals and patterns stay '
            'on your phone.',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 20),
          ...List.generate(_drafts.length, (i) {
            final d = _drafts[i];
            return _GoalCard(
              index: i,
              draft: d,
              canRemove: _drafts.length > 1,
              onPickTime: () => _pickTime(i),
              onRemove: () => _removeGoal(i),
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addGoal,
            icon: const Icon(Icons.add),
            label: const Text('Add another goal'),
          ),
          const SizedBox(height: 8),
          Text(
            'Reminder voice',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The app learns simple themes from your defer reasons (work, tired, etc.) '
            '— on-device only. Follow-up lines lean on that. Pick a style; "Auto" '
            'rotates daily so references stay fresh.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _voicePackId,
            decoration: const InputDecoration(
              labelText: 'Voice / meme layer',
            ),
            items: const [
              DropdownMenuItem(
                value: kPackAuto,
                child: Text('Auto — rotates daily'),
              ),
              DropdownMenuItem(
                value: kPackClassic,
                child: Text('Straight talk'),
              ),
              DropdownMenuItem(
                value: kPackEmoji,
                child: Text('Emoji / compact'),
              ),
              DropdownMenuItem(
                value: kPackGrinder,
                child: Text('Grinder refs (boats & logs energy)'),
              ),
            ],
            onChanged: _busy
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() => _voicePackId = v);
                  },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _lockIn,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('LOCK IN'),
          ),
          const SizedBox(height: 12),
          Text(
            'Grant notification permission when prompted. SMS would need a phone '
            'number and a paid service; this build uses daily lock-screen reminders '
            'instead.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalDraft {
  _GoalDraft({
    required this.id,
    required String title,
    required String message,
    required String checkInQuestion,
    required this.hour,
    required this.minute,
  })  : titleController = TextEditingController(text: title),
        messageController = TextEditingController(text: message),
        checkInQuestionController =
            TextEditingController(text: checkInQuestion);

  final String id;
  final TextEditingController titleController;
  final TextEditingController messageController;
  final TextEditingController checkInQuestionController;
  int hour;
  int minute;

  void dispose() {
    titleController.dispose();
    messageController.dispose();
    checkInQuestionController.dispose();
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onPickTime,
    required this.onRemove,
  });

  final int index;
  final _GoalDraft draft;
  final bool canRemove;
  final VoidCallback onPickTime;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel = TimeOfDay(hour: draft.hour, minute: draft.minute)
        .format(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Goal ${index + 1}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove goal',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Short title (notification title)',
                hintText: 'e.g. Gym',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.messageController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reminder message',
                hintText: 'e.g. Did you hit legs today?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.checkInQuestionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Check-in question (after you tap a reminder)',
                hintText: 'e.g. Did you go to the gym yet?',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily reminder time'),
              subtitle: Text(timeLabel),
              trailing: const Icon(Icons.schedule),
              onTap: onPickTime,
            ),
          ],
        ),
      ),
    );
  }
}
