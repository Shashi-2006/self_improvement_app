// ─────────────────────────────────────────────────────────────────────────────
// XP CALCULATOR — pure maths, no Flutter, no phone. Easy to test.
//
// THE RULES (from the spec, decided 25 Nov 2026):
//  1. XP is proportional to time done, not all-or-nothing.
//     XP = full XP x (elapsed / target). 30 min of a 60 min session = half.
//  2. XP per hour depends on the task and is decided by the app owner.
//     Study 100/hr, Gym 80/hr, Wake 40/day, Sleep 40/day,
//     Water 10 XP per 500 ml, max 50 XP/day.
//  3. ZERO-TIME RULE: elapsed 0:00 = 0 XP. No mood bonus either.
//  4. A partial session earns XP but does NOT count for the streak — only a
//     session that reaches the full target time completes the day.
// ─────────────────────────────────────────────────────────────────────────────

/// The owner's XP rates. The owner (Shashwat) can edit these in Settings;
/// they are saved with the rest of the app state. New habits pick a level
/// (Low / Medium / High) and the app suggests a rate from this table.
class XpRates {
  const XpRates({
    this.studyPerHour = 100,
    this.gymPerHour = 80,
    this.wakePerDay = 40,
    this.sleepPerDay = 40,
    this.waterPer500ml = 10,
    this.waterMaxPerDay = 50,
  });

  final int studyPerHour;
  final int gymPerHour;
  final int wakePerDay;
  final int sleepPerDay;

  /// XP for one 500 ml water log.
  final int waterPer500ml;

  /// Water XP stops here each day, so water can never farm XP.
  final int waterMaxPerDay;

  /// The full XP for one hour of the habit with this id.
  int perHourFor(String habitId) {
    switch (habitId) {
      case 'study':
        return studyPerHour;
      case 'gym':
        return gymPerHour;
      default:
        return gymPerHour;
    }
  }

  /// The flat XP for completing a check-in habit once a day.
  int perDayFor(String habitId) {
    switch (habitId) {
      case 'wake':
        return wakePerDay;
      case 'sleep':
        return sleepPerDay;
      default:
        return 0;
    }
  }

  Map<String, dynamic> toJson() => {
        'studyPerHour': studyPerHour,
        'gymPerHour': gymPerHour,
        'wakePerDay': wakePerDay,
        'sleepPerDay': sleepPerDay,
        'waterPer500ml': waterPer500ml,
        'waterMaxPerDay': waterMaxPerDay,
      };

  factory XpRates.fromJson(Map<String, dynamic> json) => XpRates(
        studyPerHour: json['studyPerHour'] as int? ?? 100,
        gymPerHour: json['gymPerHour'] as int? ?? 80,
        wakePerDay: json['wakePerDay'] as int? ?? 40,
        sleepPerDay: json['sleepPerDay'] as int? ?? 40,
        waterPer500ml: json['waterPer500ml'] as int? ?? 10,
        waterMaxPerDay: json['waterMaxPerDay'] as int? ?? 50,
      );

  XpRates copyWith({
    int? studyPerHour,
    int? gymPerHour,
    int? wakePerDay,
    int? sleepPerDay,
    int? waterPer500ml,
    int? waterMaxPerDay,
  }) =>
      XpRates(
        studyPerHour: studyPerHour ?? this.studyPerHour,
        gymPerHour: gymPerHour ?? this.gymPerHour,
        wakePerDay: wakePerDay ?? this.wakePerDay,
        sleepPerDay: sleepPerDay ?? this.sleepPerDay,
        waterPer500ml: waterPer500ml ?? this.waterPer500ml,
        waterMaxPerDay: waterMaxPerDay ?? this.waterMaxPerDay,
      );
}

/// XP for a timed session.
///
/// [elapsedSeconds] — how long the timer actually ran.
/// [targetSeconds] — how long the session was supposed to last.
/// [fullXp] — the XP a full session is worth (e.g. 80 for a gym hour).
///
/// Examples: 60 min of 60 at 80 XP = 80. 30 min = 40. 5 min = 6.
/// 0 seconds = 0, always.
int xpForSession({
  required int elapsedSeconds,
  required int targetSeconds,
  required int fullXp,
}) {
  if (elapsedSeconds <= 0 || targetSeconds <= 0 || fullXp <= 0) return 0;
  if (elapsedSeconds >= targetSeconds) return fullXp;
  // Integer maths on purpose: 5 min of 60 at 80 XP = 80*300/3600 = 6.
  return (fullXp * elapsedSeconds) ~/ targetSeconds;
}

/// XP for one water log, before the daily cap is applied.
/// 500 ml = full rate, 250 ml = half, 100 ml = a fifth (rounded down,
/// minimum 1 XP for any real log, 0 for a 0 ml log).
int xpForWaterLog({required int ml, required int xpPer500ml}) {
  if (ml <= 0) return 0;
  final xp = (xpPer500ml * ml) ~/ 500;
  return xp < 1 ? 1 : xp;
}

/// Level from total XP. Level 1 needs 100 XP, level 2 needs 200 more, and so
/// on — the bar grows by 100 each level, like the old QuestLog demo did.
({int level, int xpIntoLevel, int xpForNextLevel}) levelFor(int totalXp) {
  var level = 1;
  var remaining = totalXp < 0 ? 0 : totalXp;
  var needed = 100;
  while (remaining >= needed) {
    remaining -= needed;
    level += 1;
    needed += 100;
  }
  return (level: level, xpIntoLevel: remaining, xpForNextLevel: needed);
}
