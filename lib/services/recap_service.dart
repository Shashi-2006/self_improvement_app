// ─────────────────────────────────────────────────────────────────────────────
// RECAP SERVICE — end-of-day recap, weekly totals, reality-check projection.
//
// All of these are just counting: the app already stores every check-in, so
// a recap is a short sentence built from counts. No AI needed.
// ─────────────────────────────────────────────────────────────────────────────

/// What happened on one day, for the recap and the weekly chart.
class DaySummary {
  DaySummary({
    required this.date,
    required this.doneHabitIds,
    required this.missedHabitIds,
    required this.xpEarned,
    required this.waterMl,
    required this.wastedMinutes,
    required this.utilisedMinutes,
  });

  final String date;
  final List<String> doneHabitIds;
  final List<String> missedHabitIds;
  final int xpEarned;
  final int waterMl;

  /// Planned habit minutes missed + excess screen time on reduced apps.
  final int wastedMinutes;

  /// Minutes of habits actually completed.
  final int utilisedMinutes;
}

/// Builds "You were good today — gym done, 4L water. You missed study
/// today, and you missed gym yesterday too. Keep it up tomorrow."
String buildEndOfDayRecap({
  required DaySummary today,
  required DaySummary yesterday,
  required Map<String, String> habitNames,
}) {
  final buffer = StringBuffer();
  if (today.doneHabitIds.isEmpty && today.missedHabitIds.isEmpty) {
    return 'A quiet day — nothing planned and nothing done. '
        'Tomorrow is a fresh start.';
  }

  final doneNames =
      today.doneHabitIds.map((id) => habitNames[id] ?? id).toList();
  final missedNames =
      today.missedHabitIds.map((id) => habitNames[id] ?? id).toList();

  if (doneNames.isNotEmpty) {
    buffer.write('You were good today — ${doneNames.join(', ')} done');
    if (today.waterMl > 0) {
      buffer.write(', ${(today.waterMl / 1000).toStringAsFixed(1)}L water');
    }
    buffer.write('. ');
  } else {
    buffer.write('Nothing ticked off today. ');
  }

  if (missedNames.isNotEmpty) {
    buffer.write('You missed ${missedNames.join(', ')} today');
    final missedAgain = missedNames.where(
      (name) => yesterday.missedHabitIds
          .map((id) => habitNames[id] ?? id)
          .contains(name),
    );
    if (missedAgain.isNotEmpty) {
      buffer.write(', and you missed ${missedAgain.join(', ')} yesterday too');
    }
    buffer.write('. ');
  }
  buffer.write('Keep it up tomorrow.');
  return buffer.toString();
}

/// The reality-check projection from the spec.
/// Example: Instagram 3h vs 1h limit = 2h wasted a day.
/// Keep that up: 14h a week, ~60h a month = 60 gym sessions.
String realityCheckProjection({required int wastedMinutesPerDay}) {
  if (wastedMinutesPerDay <= 0) {
    return 'No wasted time today — every hour went where you wanted it to.';
  }
  final perWeekHours = wastedMinutesPerDay * 7 / 60;
  final perMonthHours = wastedMinutesPerDay * 30 / 60;
  final gymSessions = perMonthHours.round();
  String hours(double h) =>
      h == h.roundToDouble() ? h.round().toString() : h.toStringAsFixed(1);
  return 'At this rate you lose ${hours(wastedMinutesPerDay / 60)}h a day — '
      '${hours(perWeekHours)}h a week, about ${hours(perMonthHours)}h a month. '
      'That is $gymSessions gym sessions, or $gymSessions hours of study, '
      'you could have built instead.';
}

/// Weekly totals for the chart: utilised vs wasted minutes per day.
({int utilisedMinutes, int wastedMinutes}) weeklyTotals(
  List<DaySummary> days,
) {
  var utilised = 0;
  var wasted = 0;
  for (final day in days) {
    utilised += day.utilisedMinutes;
    wasted += day.wastedMinutes;
  }
  return (utilisedMinutes: utilised, wastedMinutes: wasted);
}

/// A friendly nudge for a missed habit — honest, never shaming.
String nudgeForMissedHabit(String habitName) =>
    'You missed $habitName today — no stress. One small start tomorrow '
    'counts: even 10 minutes keeps the habit alive.';
