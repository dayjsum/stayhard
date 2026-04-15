/// A same-day promise the user made after saying "not yet" on a check-in.
class Commitment {
  Commitment({
    required this.goalId,
    required this.dateKey,
    required this.hour,
    required this.minute,
    this.reason,
  });

  final String goalId;
  /// Local calendar date `yyyy-MM-dd`.
  final String dateKey;
  final int hour;
  final int minute;
  final String? reason;

  Map<String, dynamic> toJson() => {
        'goalId': goalId,
        'dateKey': dateKey,
        'hour': hour,
        'minute': minute,
        if (reason != null && reason!.isNotEmpty) 'reason': reason,
      };

  factory Commitment.fromJson(Map<String, dynamic> json) => Commitment(
        goalId: json['goalId'] as String,
        dateKey: json['dateKey'] as String,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        reason: json['reason'] as String?,
      );
}
