class GoalItem {
  GoalItem({
    required this.id,
    required this.title,
    required this.reminderMessage,
    required this.hour,
    required this.minute,
    this.checkInQuestion,
    Map<int, ({int hour, int minute})>? learnedCommitByWeekday,
  }) : learnedCommitByWeekday = learnedCommitByWeekday ?? {};

  final String id;
  final String title;
  final String reminderMessage;
  final int hour;
  final int minute;

  /// Shown on check-in, e.g. "Did you go to the gym yet?"
  final String? checkInQuestion;

  /// Last committed time the user chose for a weekday (Mon=1 … Sun=7).
  final Map<int, ({int hour, int minute})> learnedCommitByWeekday;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'reminderMessage': reminderMessage,
        'hour': hour,
        'minute': minute,
        if (checkInQuestion != null && checkInQuestion!.isNotEmpty)
          'checkInQuestion': checkInQuestion,
        if (learnedCommitByWeekday.isNotEmpty)
          'learnedByWeekday': {
            for (final e in learnedCommitByWeekday.entries)
              e.key.toString(): <String, int>{
                'h': e.value.hour,
                'm': e.value.minute,
              },
          },
      };

  factory GoalItem.fromJson(Map<String, dynamic> json) {
    final learnedRaw = json['learnedByWeekday'];
    final learned = <int, ({int hour, int minute})>{};
    if (learnedRaw is Map) {
      for (final e in learnedRaw.entries) {
        final day = int.tryParse(e.key.toString());
        final m = Map<String, dynamic>.from(e.value as Map);
        if (day != null) {
          learned[day] = (
            hour: m['h'] as int? ?? 17,
            minute: m['m'] as int? ?? 0,
          );
        }
      }
    }
    return GoalItem(
      id: json['id'] as String,
      title: json['title'] as String,
      reminderMessage: json['reminderMessage'] as String,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      checkInQuestion: json['checkInQuestion'] as String?,
      learnedCommitByWeekday: learned,
    );
  }

  GoalItem copyWith({
    String? id,
    String? title,
    String? reminderMessage,
    int? hour,
    int? minute,
    String? checkInQuestion,
    Map<int, ({int hour, int minute})>? learnedCommitByWeekday,
  }) {
    return GoalItem(
      id: id ?? this.id,
      title: title ?? this.title,
      reminderMessage: reminderMessage ?? this.reminderMessage,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      checkInQuestion: checkInQuestion ?? this.checkInQuestion,
      learnedCommitByWeekday:
          learnedCommitByWeekday ?? this.learnedCommitByWeekday,
    );
  }

  /// Merge learned slot for [weekday] (DateTime.weekday).
  GoalItem withLearnedCommit(int weekday, int hour, int minute) {
    final next = Map<int, ({int hour, int minute})>.from(
      learnedCommitByWeekday,
    );
    next[weekday] = (hour: hour, minute: minute);
    return copyWith(learnedCommitByWeekday: next);
  }
}
