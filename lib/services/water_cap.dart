// ─────────────────────────────────────────────────────────────────────────────
// WATER CAP — pure logic, no Flutter. Easy to test.
//
// WHY THERE IS A CAP: water is logged in small pieces through the day. Without
// a cap a user could log the whole 5 L at once and "complete" the goal without
// drinking it. The cap is also a safety rule, from research done 25 Nov 2026:
//
//  * Kidneys clear about 0.8–1.0 L of water per hour — that is the speed
//    limit, not the daily total. 1250 ml in one go is already over it.
//  * One or two glasses (250–500 ml) at a time is comfortable.
//
// THE RULE (as a percentage of the daily goal, so it scales if the goal
// changes — a 3 L goal gets a 300 ml cap, a 5 L goal gets 500 ml):
//  * Per-entry cap: 10% of the daily goal  (500 ml for a 5 L goal)
//  * Hourly cap:    20% of the daily goal  (1000 ml per hour for a 5 L goal)
//  * Cooldown: when the hourly cap is hit, the app shows "next log in X min".
//
// This file is general health guidance, not medical advice for anyone.
// ─────────────────────────────────────────────────────────────────────────────

import '../models/app_models.dart';

/// The answer to "can I log this much water right now?"
class WaterCapResult {
  const WaterCapResult({
    required this.allowed,
    required this.maxPerLogMl,
    required this.maxPerHourMl,
    this.blockedReason,
    this.nextLogIn,
  });

  /// True when this log may be saved.
  final bool allowed;

  /// Largest single log allowed (10% of the daily goal).
  final int maxPerLogMl;

  /// Largest total allowed inside any rolling 60 minutes (20% of goal).
  final int maxPerHourMl;

  /// Human-readable reason when [allowed] is false.
  final String? blockedReason;

  /// When the next log becomes possible (only set when blocked by the
  /// hourly cap). The UI shows "next log in X min" from this.
  final Duration? nextLogIn;
}

/// Checks one water log against the caps.
///
/// [amountMl] — what the user wants to log now.
/// [dailyGoalMl] — the day's water goal (5000 by default).
/// [logs] — today's logs so far, newest last.
/// [now] — the current time (a parameter, not DateTime.now(), so tests can
/// control time).
WaterCapResult canLogWater({
  required int amountMl,
  required int dailyGoalMl,
  required List<WaterLog> logs,
  required DateTime now,
}) {
  // 10% per log, 20% per hour. Integer division is fine: 5000 -> 500 / 1000.
  final maxPerLogMl = dailyGoalMl ~/ 10;
  final maxPerHourMl = dailyGoalMl ~/ 5;

  if (amountMl <= 0) {
    return WaterCapResult(
      allowed: false,
      maxPerLogMl: maxPerLogMl,
      maxPerHourMl: maxPerHourMl,
      blockedReason: 'Log at least a sip — 0 ml earns nothing.',
    );
  }

  if (amountMl > maxPerLogMl) {
    return WaterCapResult(
      allowed: false,
      maxPerLogMl: maxPerLogMl,
      maxPerHourMl: maxPerHourMl,
      blockedReason:
          'Max $maxPerLogMl ml per log — that is 10% of your daily goal. '
          'Spread it out instead of drinking it all at once.',
    );
  }

  // Rolling 60-minute window: only logs from the last hour count.
  final hourAgo = now.subtract(const Duration(hours: 1));
  final recentLogs = logs.where((l) => l.at.isAfter(hourAgo)).toList();
  final mlInLastHour =
      recentLogs.fold<int>(0, (sum, l) => sum + l.ml);

  if (mlInLastHour + amountMl > maxPerHourMl) {
    // The next log becomes possible when the oldest log in the window
    // slides out of the last 60 minutes.
    final oldest = recentLogs
        .map((l) => l.at)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final nextLogIn = oldest.add(const Duration(hours: 1)).difference(now);
    final minutes = nextLogIn.inMinutes < 1 ? 1 : nextLogIn.inMinutes;
    return WaterCapResult(
      allowed: false,
      maxPerLogMl: maxPerLogMl,
      maxPerHourMl: maxPerHourMl,
      blockedReason:
          'Hourly cap reached — max $maxPerHourMl ml per hour. '
          'Your kidneys clear about 1 L per hour.',
      nextLogIn: Duration(minutes: minutes),
    );
  }

  return WaterCapResult(
    allowed: true,
    maxPerLogMl: maxPerLogMl,
    maxPerHourMl: maxPerHourMl,
  );
}

/// How much water is left to reach the goal today.
int waterRemainingMl({required int dailyGoalMl, required List<WaterLog> logs}) {
  final drunk = logs.fold<int>(0, (sum, l) => sum + l.ml);
  final remaining = dailyGoalMl - drunk;
  return remaining < 0 ? 0 : remaining;
}
