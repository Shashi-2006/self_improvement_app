// ─────────────────────────────────────────────────────────────────────────────
// MODELS — the plain data of the app.
//
// A "model" is just a Dart class that holds data (like a row in a table).
// Models have no UI and no logic that talks to the phone — they only describe
// WHAT the app stores. The services in lib/services/ decide HOW it is used.
// Every model can turn itself into JSON (toJson) and back (fromJson), because
// that is how it is saved on the phone (SharedPreferences) and how it will be
// sent to Firestore later.
// ─────────────────────────────────────────────────────────────────────────────

/// The kind of a habit. A [HabitKind.timer] habit is done in one timed block
/// (gym, study). A [HabitKind.checkIn] habit is one tap a day (wake up early,
/// sleep on time). A [HabitKind.log] habit is logged in small pieces through
/// the day (water).
enum HabitKind { timer, checkIn, log }

/// One habit the user is building, e.g. Gym, Study, Wake up early.
class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.kind,
    required this.icon,
    required this.targetMinutes,
    required this.windowStart,
    required this.windowEnd,
    required this.preferredStart,
    this.frequencyPerWeek = 7,
    this.waterGoalMl,
    this.xpPerHour,
    this.xpPerDay,
    this.xpPerLog,
  });

  /// Short stable id, e.g. "gym". Never shown to the user.
  final String id;
  final String name;
  final HabitKind kind;

  /// An emoji shown on the card. Emojis are free — no image files needed.
  final String icon;

  /// Minutes the session should last (timer habits). 60 for gym / study.
  final int targetMinutes;

  /// Allowed time window, as "16:00" style 24-hour strings.
  final String windowStart;
  final String windowEnd;

  /// Preferred start inside the window, e.g. "16:00" for gym (4–5 pm).
  final String preferredStart;

  /// How many days per week this habit is planned (gym = 3).
  final int frequencyPerWeek;

  /// Daily water goal in ml. Only set for the water habit (5000).
  final int? waterGoalMl;

  /// XP overrides. When null, the app uses the owner's default rates in
  /// XpRates (see lib/services/xp_calculator.dart). The owner can edit them
  /// in Settings — that is the "XP by task, owner decides" rule.
  final int? xpPerHour;
  final int? xpPerDay;
  final int? xpPerLog;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'icon': icon,
        'targetMinutes': targetMinutes,
        'windowStart': windowStart,
        'windowEnd': windowEnd,
        'preferredStart': preferredStart,
        'frequencyPerWeek': frequencyPerWeek,
        'waterGoalMl': waterGoalMl,
        'xpPerHour': xpPerHour,
        'xpPerDay': xpPerDay,
        'xpPerLog': xpPerLog,
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: HabitKind.values.byName(json['kind'] as String),
        icon: json['icon'] as String,
        targetMinutes: json['targetMinutes'] as int,
        windowStart: json['windowStart'] as String,
        windowEnd: json['windowEnd'] as String,
        preferredStart: json['preferredStart'] as String,
        frequencyPerWeek: json['frequencyPerWeek'] as int? ?? 7,
        waterGoalMl: json['waterGoalMl'] as int?,
        xpPerHour: json['xpPerHour'] as int?,
        xpPerDay: json['xpPerDay'] as int?,
        xpPerLog: json['xpPerLog'] as int?,
      );

  Habit copyWith({
    int? targetMinutes,
    String? windowStart,
    String? windowEnd,
    String? preferredStart,
    int? frequencyPerWeek,
    int? xpPerHour,
    int? xpPerDay,
    int? xpPerLog,
  }) =>
      Habit(
        id: id,
        name: name,
        kind: kind,
        icon: icon,
        targetMinutes: targetMinutes ?? this.targetMinutes,
        windowStart: windowStart ?? this.windowStart,
        windowEnd: windowEnd ?? this.windowEnd,
        preferredStart: preferredStart ?? this.preferredStart,
        frequencyPerWeek: frequencyPerWeek ?? this.frequencyPerWeek,
        waterGoalMl: waterGoalMl,
        xpPerHour: xpPerHour ?? this.xpPerHour,
        xpPerDay: xpPerDay ?? this.xpPerDay,
        xpPerLog: xpPerLog ?? this.xpPerLog,
      );
}

/// One finished (or partially finished) timer session.
class HabitSession {
  HabitSession({
    required this.habitId,
    required this.date,
    required this.elapsedSeconds,
    required this.xpEarned,
    this.mood,
    this.completed = false,
  });

  final String habitId;

  /// "2026-11-25" — the day the session happened.
  final String date;

  /// How many seconds the timer actually ran. 0 means "started and stopped
  /// immediately" and must earn 0 XP (the zero-time rule).
  final int elapsedSeconds;

  final int xpEarned;

  /// How the user felt afterwards: "Great", "Okay", "Tired", ...
  final String? mood;

  /// True only when the full target time was reached. A partial session earns
  /// XP but does NOT count for the streak.
  final bool completed;

  Map<String, dynamic> toJson() => {
        'habitId': habitId,
        'date': date,
        'elapsedSeconds': elapsedSeconds,
        'xpEarned': xpEarned,
        'mood': mood,
        'completed': completed,
      };

  factory HabitSession.fromJson(Map<String, dynamic> json) => HabitSession(
        habitId: json['habitId'] as String,
        date: json['date'] as String,
        elapsedSeconds: json['elapsedSeconds'] as int,
        xpEarned: json['xpEarned'] as int,
        mood: json['mood'] as String?,
        completed: json['completed'] as bool? ?? false,
      );
}

/// One water log entry, e.g. 500 ml at 10:30.
class WaterLog {
  WaterLog({required this.at, required this.ml});

  final DateTime at;
  final int ml;

  Map<String, dynamic> toJson() =>
      {'at': at.toIso8601String(), 'ml': ml};

  factory WaterLog.fromJson(Map<String, dynamic> json) => WaterLog(
        at: DateTime.parse(json['at'] as String),
        ml: json['ml'] as int,
      );
}

/// One habit inside a weekly plan, as produced by the planner.
class PlannedHabit {
  PlannedHabit({
    required this.habitId,
    required this.name,
    required this.frequencyPerWeek,
    required this.durationMinutes,
    required this.windowStart,
    required this.windowEnd,
    required this.preferredStart,
    this.waterGoalMl,
  });

  final String habitId;
  final String name;
  final int frequencyPerWeek;
  final int durationMinutes;
  final String windowStart;
  final String windowEnd;
  final String preferredStart;
  final int? waterGoalMl;

  Map<String, dynamic> toJson() => {
        'habitId': habitId,
        'name': name,
        'frequencyPerWeek': frequencyPerWeek,
        'durationMinutes': durationMinutes,
        'windowStart': windowStart,
        'windowEnd': windowEnd,
        'preferredStart': preferredStart,
        'waterGoalMl': waterGoalMl,
      };

  factory PlannedHabit.fromJson(Map<String, dynamic> json) => PlannedHabit(
        habitId: json['habitId'] as String,
        name: json['name'] as String,
        frequencyPerWeek: json['frequencyPerWeek'] as int,
        durationMinutes: json['durationMinutes'] as int,
        windowStart: json['windowStart'] as String,
        windowEnd: json['windowEnd'] as String,
        preferredStart: json['preferredStart'] as String,
        waterGoalMl: json['waterGoalMl'] as int?,
      );

  PlannedHabit copyWith({
    int? frequencyPerWeek,
    int? durationMinutes,
    String? windowStart,
    String? windowEnd,
    String? preferredStart,
  }) =>
      PlannedHabit(
        habitId: habitId,
        name: name,
        frequencyPerWeek: frequencyPerWeek ?? this.frequencyPerWeek,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        windowStart: windowStart ?? this.windowStart,
        windowEnd: windowEnd ?? this.windowEnd,
        preferredStart: preferredStart ?? this.preferredStart,
        waterGoalMl: waterGoalMl,
      );
}

/// A whole week the user described in plain words and confirmed.
class WeeklyPlan {
  WeeklyPlan({required this.text, required this.habits, required this.createdAt});

  /// The exact words the user typed.
  final String text;
  final List<PlannedHabit> habits;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'text': text,
        'habits': habits.map((h) => h.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory WeeklyPlan.fromJson(Map<String, dynamic> json) => WeeklyPlan(
        text: json['text'] as String,
        habits: (json['habits'] as List)
            .map((e) => PlannedHabit.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// How the user tags one app's time. NEVER hard-coded for ambiguous apps —
/// the user decides, and can change it any time.
enum UsageTag { productive, nonProductive, unclassified }

/// One app's screen time for one day.
class AppUsageEntry {
  AppUsageEntry({
    required this.appName,
    required this.packageName,
    required this.minutesToday,
    required this.minutesYesterday,
    required this.minutesLastWeek,
    required this.tag,
    this.isGame = false,
    this.dailyLimitMinutes,
  });

  final String appName;

  /// Android package, e.g. "com.instagram.android". Empty for demo data.
  final String packageName;
  final int minutesToday;
  final int minutesYesterday;

  /// Total minutes this app took last week (for the orbit delta).
  final int minutesLastWeek;
  final UsageTag tag;
  final bool isGame;

  /// The daily limit the user set, if any. Null = no limit.
  final int? dailyLimitMinutes;

  /// Minutes over the limit today. 0 when inside the limit or no limit set.
  int get minutesOverLimit {
    if (dailyLimitMinutes == null) return 0;
    final over = minutesToday - dailyLimitMinutes!;
    return over > 0 ? over : 0;
  }

  /// Weekly change vs last week, in minutes. Positive = used more.
  int get weeklyDeltaMinutes => minutesToday * 7 - minutesLastWeek;

  AppUsageEntry copyWith({UsageTag? tag, int? dailyLimitMinutes}) =>
      AppUsageEntry(
        appName: appName,
        packageName: packageName,
        minutesToday: minutesToday,
        minutesYesterday: minutesYesterday,
        minutesLastWeek: minutesLastWeek,
        tag: tag ?? this.tag,
        isGame: isGame,
        dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      );

  Map<String, dynamic> toJson() => {
        'appName': appName,
        'packageName': packageName,
        'minutesToday': minutesToday,
        'minutesYesterday': minutesYesterday,
        'minutesLastWeek': minutesLastWeek,
        'tag': tag.name,
        'isGame': isGame,
        'dailyLimitMinutes': dailyLimitMinutes,
      };

  factory AppUsageEntry.fromJson(Map<String, dynamic> json) => AppUsageEntry(
        appName: json['appName'] as String,
        packageName: json['packageName'] as String? ?? '',
        minutesToday: json['minutesToday'] as int,
        minutesYesterday: json['minutesYesterday'] as int,
        minutesLastWeek: json['minutesLastWeek'] as int,
        tag: UsageTag.values.byName(json['tag'] as String),
        isGame: json['isGame'] as bool? ?? false,
        dailyLimitMinutes: json['dailyLimitMinutes'] as int?,
      );
}

/// One row of a leaderboard.
class LeaderboardEntry {
  LeaderboardEntry({
    required this.name,
    required this.xp,
    this.isYou = false,
  });

  final String name;
  final int xp;
  final bool isYou;
}

/// One message in a habit-only group chat.
class ChatMessage {
  ChatMessage({
    required this.author,
    required this.text,
    required this.at,
    this.isYou = false,
  });

  final String author;
  final String text;
  final DateTime at;
  final bool isYou;

  Map<String, dynamic> toJson() => {
        'author': author,
        'text': text,
        'at': at.toIso8601String(),
        'isYou': isYou,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        author: json['author'] as String,
        text: json['text'] as String,
        at: DateTime.parse(json['at'] as String),
        isYou: json['isYou'] as bool? ?? false,
      );
}
