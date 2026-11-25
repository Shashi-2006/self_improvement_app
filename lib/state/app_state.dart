// ─────────────────────────────────────────────────────────────────────────────
// APP STATE — the single place that owns all of the app's data.
//
// PATTERN: this is the "ChangeNotifier" pattern — the beginner-friendly
// version of state management. The state object holds the data; whenever it
// changes it calls notifyListeners(), and every screen listening rebuilds.
// (Bigger apps often use Riverpod or Bloc. They solve the same problem with
// more ceremony. For one person's first app, ChangeNotifier is the right
// size — and it is exactly what the Flutter docs teach first.)
//
// WHAT LIVES HERE:
//  * the 5 habits, the XP rates, total XP, streak
//  * the active timer (start / pause / resume / finish — pausing never
//    loses time, because elapsed time is saved, not just shown)
//  * water logs, weekly plan, screen-time entries, leaderboard, chat
//  * light / dark theme choice
//  * saving everything to the phone (LocalStore) after every change
//
// WHAT DOES NOT LIVE HERE: the maths (xp_calculator, water_cap), the
// parsing (plan_parser) and the phone permissions (screen_time_service,
// focus_lock_service). State asks those services for answers; it does not
// re-implement them.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/firebase_backend.dart';
import '../services/focus_lock_service.dart';
import '../services/local_store.dart';
import '../services/plan_parser.dart';
import '../services/recap_service.dart';
import '../services/screen_time_service.dart';
import '../services/water_cap.dart';
import '../services/xp_calculator.dart';

/// The five habits the app ships with, straight from the spec.
List<Habit> defaultHabits() => [
      Habit(
        id: 'gym',
        name: 'Gym',
        kind: HabitKind.timer,
        icon: '🏋️',
        targetMinutes: 60,
        windowStart: '16:00',
        windowEnd: '18:00',
        preferredStart: '16:00',
        frequencyPerWeek: 3,
      ),
      Habit(
        id: 'study',
        name: 'Study',
        kind: HabitKind.timer,
        icon: '📚',
        targetMinutes: 60,
        windowStart: '09:00',
        windowEnd: '21:00',
        preferredStart: '09:00',
      ),
      Habit(
        id: 'wake',
        name: 'Wake up early',
        kind: HabitKind.checkIn,
        icon: '🌅',
        targetMinutes: 0,
        windowStart: '05:00',
        windowEnd: '07:00',
        preferredStart: '06:00',
      ),
      Habit(
        id: 'sleep',
        name: 'Sleep on time',
        kind: HabitKind.checkIn,
        icon: '😴',
        targetMinutes: 0,
        windowStart: '22:00',
        windowEnd: '23:00',
        preferredStart: '22:30',
      ),
      Habit(
        id: 'water',
        name: 'Drink water',
        kind: HabitKind.log,
        icon: '💧',
        targetMinutes: 0,
        windowStart: '07:00',
        windowEnd: '22:00',
        preferredStart: '07:00',
        waterGoalMl: 5000,
      ),
    ];

/// Seeded friends for the leaderboard (demo until Firebase is wired).
List<LeaderboardEntry> demoLeaderboard(String yourName, int yourXp) {
  final entries = [
    LeaderboardEntry(name: 'Aarav', xp: 1240),
    LeaderboardEntry(name: 'Meera', xp: 1180),
    LeaderboardEntry(name: yourName, xp: yourXp, isYou: true),
    LeaderboardEntry(name: 'Rohan', xp: 860),
    LeaderboardEntry(name: 'Priya', xp: 720),
    LeaderboardEntry(name: 'Kabir', xp: 540),
  ];
  entries.sort((a, b) => b.xp.compareTo(a.xp));
  return entries;
}

/// Seeded Gym Crew chat (demo until Firebase is wired).
List<ChatMessage> demoChatMessages() {
  final now = DateTime.now();
  return [
    ChatMessage(
      author: 'Meera',
      text: 'Day 12 of the streak — the 4 pm slot finally feels automatic.',
      at: now.subtract(const Duration(hours: 5)),
    ),
    ChatMessage(
      author: 'Aarav',
      text: 'Same. What helped me was laying out gym clothes the night before.',
      at: now.subtract(const Duration(hours: 4, minutes: 40)),
    ),
    ChatMessage(
      author: 'Rohan',
      text: 'How do you all handle the days you really don\'t feel like going?',
      at: now.subtract(const Duration(hours: 2)),
    ),
    ChatMessage(
      author: 'Meera',
      text: 'I just do 10 minutes. Usually I stay for the full hour once I\'m there.',
      at: now.subtract(const Duration(hours: 1, minutes: 30)),
    ),
  ];
}

/// The timer's state machine: idle -> running -> paused -> running -> done.
/// "Paused" is a real state, not a dead end — Resume continues from the
/// saved elapsed seconds, Finish banks the XP earned so far.
enum TimerStatus { idle, running, paused }

class AppState extends ChangeNotifier {
  AppState({LocalStore? store, AuthService? auth})
      : _store = store ?? LocalStore(),
        _auth = auth ?? AuthService(),
        _planner = RuleBasedPlanner(),
        _screenTime = ScreenTimeService(),
        _focusLock = FocusLockService(),
        _backend = LocalBackend(
          seedMessages: demoChatMessages(),
          seedLeaderboard: demoLeaderboard('You', 0),
        ) {
    _focusLock.onBlockedAppDetected = (appName) {
      focusBlockedMessage =
          '$appName is blocked during this focus session — back to your timer.';
      notifyListeners();
    };
  }

  final LocalStore _store;
  final AuthService _auth;
  final WeeklyPlanner _planner;
  final ScreenTimeService _screenTime;
  final FocusLockService _focusLock;
  final Backend _backend;

  AuthService get auth => _auth;

  bool _loaded = false;
  bool get loaded => _loaded;

  // ── Auth / demo ───────────────────────────────────────────────────────────
  /// Email of the signed-in account, or null when nobody is signed in.
  String? signedInEmail;

  /// True while the app is running in Demo Mode: sample data, read-only.
  /// Enforced HERE, in the state layer — every method that would change
  /// data checks this flag first. Hiding a button is not enough; the
  /// methods themselves refuse, so no screen can accidentally write.
  bool demoMode = false;

  /// Set whenever a demo-mode write is refused, so the UI can explain why.
  String? demoBlockedMessage;

  bool get isSignedIn => signedInEmail != null;

  void _blockDemo(String action) {
    demoBlockedMessage =
        'Demo mode is read-only — $action is not saved. '
        'Create an account to keep your own progress.';
    notifyListeners();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  List<Habit> habits = defaultHabits();
  List<HabitSession> sessions = [];
  List<WaterLog> waterLogs = [];
  XpRates xpRates = const XpRates();
  int totalXp = 0;
  int streakDays = 0;
  WeeklyPlan? plan;
  List<AppUsageEntry> usage = [];
  bool usageIsDemo = true;
  bool usagePermissionGranted = false;
  List<ChatMessage> chatMessages = [];
  bool isDarkMode = false;

  /// The last focus-lock bounce message, shown as a banner on Today.
  String? focusBlockedMessage;

  /// Shows a focus-lock bounce (used when the user taps a blocked app).
  void showFocusBlockedMessage(String message) {
    focusBlockedMessage = message;
    notifyListeners();
  }

  /// Set when a spike prompt should be shown for an unclassified app.
  AppUsageEntry? spikePromptApp;

  // ── Timer ─────────────────────────────────────────────────────────────────
  TimerStatus timerStatus = TimerStatus.idle;
  String? activeHabitId;
  int elapsedSeconds = 0;
  DateTime? _runStartedAt;
  Timer? _tick;
  bool focusLockOn = false;

  Habit? get activeHabit {
    if (activeHabitId == null) return null;
    for (final h in habits) {
      if (h.id == activeHabitId) return h;
    }
    return null;
  }

  int get activeTargetSeconds => (activeHabit?.targetMinutes ?? 60) * 60;

  /// XP the current session would earn if finished right now.
  int get currentSessionXp {
    final habit = activeHabit;
    if (habit == null) return 0;
    return xpForSession(
      elapsedSeconds: elapsedSeconds,
      targetSeconds: activeTargetSeconds,
      fullXp: xpRates.perHourFor(habit.id),
    );
  }

  /// Packages the focus lock should block: the apps the user chose to
  /// reduce, plus the non-productive defaults.
  List<String> get blockedPackages => usage
      .where((e) =>
          e.tag == UsageTag.nonProductive || e.dailyLimitMinutes != null)
      .map((e) => e.packageName)
      .where((p) => p.isNotEmpty)
      .toList();

  // ── Loading / saving ──────────────────────────────────────────────────────
  Future<void> load() async {
    // Restore the saved session (secure-storage token). A forged or
    // missing token means "nobody is signed in" — the login screen shows.
    // A platform failure here (e.g. secure storage unavailable) must never
    // brick the launch: it just means "signed out".
    try {
      signedInEmail = await _auth.restoreSession();
    } catch (_) {
      signedInEmail = null;
    }
    Map<String, dynamic>? json;
    try {
      json = await _store.loadState();
    } catch (_) {
      // Unreadable save: start fresh rather than stuck on the spinner.
      json = null;
    }
    usage = demoUsage();
    chatMessages = demoChatMessages();
    if (json != null) {
      try {
        habits = (json['habits'] as List)
            .map((e) => Habit.fromJson(e as Map<String, dynamic>))
            .toList();
        sessions = (json['sessions'] as List? ?? [])
            .map((e) => HabitSession.fromJson(e as Map<String, dynamic>))
            .toList();
        waterLogs = (json['waterLogs'] as List? ?? [])
            .map((e) => WaterLog.fromJson(e as Map<String, dynamic>))
            .toList();
        xpRates = XpRates.fromJson(
          json['xpRates'] as Map<String, dynamic>? ?? {},
        );
        totalXp = json['totalXp'] as int? ?? 0;
        streakDays = json['streakDays'] as int? ?? 0;
        isDarkMode = json['isDarkMode'] as bool? ?? false;
        if (json['plan'] != null) {
          plan = WeeklyPlan.fromJson(json['plan'] as Map<String, dynamic>);
        }
        if (json['usage'] != null) {
          usage = (json['usage'] as List)
              .map((e) => AppUsageEntry.fromJson(e as Map<String, dynamic>))
              .toList();
          usageIsDemo = json['usageIsDemo'] as bool? ?? true;
        }
        if (json['chatMessages'] != null) {
          chatMessages = (json['chatMessages'] as List)
              .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        // Restore a timer that was running/paused when the app closed.
        // Elapsed time is never lost — that is the pause/resume rule.
        final timer = json['timer'] as Map<String, dynamic>?;
        if (timer != null && timer['habitId'] != null) {
          activeHabitId = timer['habitId'] as String;
          elapsedSeconds = timer['elapsedSeconds'] as int? ?? 0;
          _elapsedBeforeRun = elapsedSeconds;
          focusLockOn = timer['focusLockOn'] as bool? ?? false;
          timerStatus = TimerStatus.paused;
        }
      } on FormatException {
        // Bad save: keep the defaults.
      }
    }
    _recomputeStreak();
    _loaded = true;
    notifyListeners();
    unawaited(refreshUsage());
  }

  Future<void> _save() async {
    // Demo mode NEVER writes: not to disk, not anywhere. The demo visitor
    // cannot change real data, because there is no write path at all.
    if (demoMode) return;
    await _store.saveState({
      'habits': habits.map((h) => h.toJson()).toList(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'waterLogs': waterLogs.map((w) => w.toJson()).toList(),
      'xpRates': xpRates.toJson(),
      'totalXp': totalXp,
      'streakDays': streakDays,
      'isDarkMode': isDarkMode,
      'plan': plan?.toJson(),
      'usage': usage.map((u) => u.toJson()).toList(),
      'usageIsDemo': usageIsDemo,
      'chatMessages': chatMessages.map((m) => m.toJson()).toList(),
      'timer': timerStatus == TimerStatus.idle
          ? null
          : {
              'habitId': activeHabitId,
              'elapsedSeconds': elapsedSeconds,
              'focusLockOn': focusLockOn,
            },
    });
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
  /// Starts the timer. [focusLockChoice] is the answer to
  /// "Do you want unproductive apps on or off during this session?"
  void startTimer(Habit habit, {required bool focusLockChoice}) {
    focusBlockedMessage = null;
    activeHabitId = habit.id;
    elapsedSeconds = 0;
    _elapsedBeforeRun = 0;
    focusLockOn = focusLockChoice;
    timerStatus = TimerStatus.running;
    _runStartedAt = DateTime.now();
    _startTicking();
    if (focusLockOn) _focusLock.startWatching(blockedPackages);
    notifyListeners();
    unawaited(_save());
  }

  void _startTicking() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_runStartedAt != null) {
        // Recompute from wall-clock time so the timer stays right even if
        // the tick was delayed while the app was in the background.
        final sinceStart =
            DateTime.now().difference(_runStartedAt!).inSeconds;
        // _runStartedAt is reset on resume, so elapsed is the sum of the
        // saved part plus this run. We store the pre-pause total separately.
        elapsedSeconds = _elapsedBeforeRun + sinceStart;
        notifyListeners();
      }
    });
  }

  int _elapsedBeforeRun = 0;

  void pauseTimer() {
    if (timerStatus != TimerStatus.running) return;
    _tick?.cancel();
    // Settle the exact elapsed time from the wall clock first, so the
    // second the tick has not fired yet is not lost.
    if (_runStartedAt != null) {
      elapsedSeconds = _elapsedBeforeRun +
          DateTime.now().difference(_runStartedAt!).inSeconds;
    }
    _elapsedBeforeRun = elapsedSeconds;
    _runStartedAt = null;
    timerStatus = TimerStatus.paused;
    _focusLock.stopWatching(); // the lock lifts while paused
    notifyListeners();
    unawaited(_save());
  }

  void resumeTimer() {
    if (timerStatus != TimerStatus.paused) return;
    timerStatus = TimerStatus.running;
    _runStartedAt = DateTime.now();
    _startTicking();
    if (focusLockOn) _focusLock.startWatching(blockedPackages);
    notifyListeners();
    unawaited(_save());
  }

  /// Finishes the session and banks the XP. [mood] is optional — when the
  /// elapsed time is 0, no mood bonus is ever added (zero-time rule).
  /// Returns false when the session was NOT saved (demo mode: the timer
  /// ran as a preview, but nothing is banked).
  bool finishTimer({String? mood}) {
    final habit = activeHabit;
    _tick?.cancel();
    _focusLock.stopWatching();
    final wasSaved = !demoMode;
    if (demoMode) {
      _blockDemo('finishing a session');
    } else if (habit != null) {
      final xp = currentSessionXp;
      final completed = elapsedSeconds >= activeTargetSeconds;
      final session = HabitSession(
        habitId: habit.id,
        date: _todayKey(),
        elapsedSeconds: elapsedSeconds,
        xpEarned: xp,
        mood: elapsedSeconds > 0 ? mood : null,
        completed: completed,
      );
      sessions.add(session);
      totalXp += xp;
      _recomputeStreak();
      unawaited(_backend.saveSession(session));
    }
    timerStatus = TimerStatus.idle;
    activeHabitId = null;
    elapsedSeconds = 0;
    _elapsedBeforeRun = 0;
    _runStartedAt = null;
    focusLockOn = false;
    notifyListeners();
    unawaited(_save());
    return wasSaved;
  }

  // ── Check-ins (wake / sleep) ──────────────────────────────────────────────
  bool checkInToday(String habitId) =>
      sessions.any((s) => s.habitId == habitId && s.date == _todayKey());

  /// Returns false when the check-in was NOT saved (already done today,
  /// or demo mode).
  bool checkIn(String habitId) {
    if (checkInToday(habitId)) return false;
    if (demoMode) {
      _blockDemo('checking in a habit');
      return false;
    }
    final xp = xpRates.perDayFor(habitId);
    sessions.add(HabitSession(
      habitId: habitId,
      date: _todayKey(),
      elapsedSeconds: 0,
      xpEarned: xp,
      completed: true,
    ));
    totalXp += xp;
    _recomputeStreak();
    notifyListeners();
    unawaited(_save());
    return true;
  }

  // ── Water ─────────────────────────────────────────────────────────────────
  Habit get waterHabit => habits.firstWhere((h) => h.id == 'water');

  List<WaterLog> get waterToday {
    final today = _todayKey();
    return waterLogs
        .where((w) =>
            '${w.at.year}-${w.at.month.toString().padLeft(2, '0')}-'
            '${w.at.day.toString().padLeft(2, '0')}' ==
            today)
        .toList();
  }

  int get waterDrunkTodayMl =>
      waterToday.fold<int>(0, (sum, w) => sum + w.ml);

  int get waterXpToday {
    var xp = 0;
    for (final log in waterToday) {
      xp += xpForWaterLog(ml: log.ml, xpPer500ml: xpRates.waterPer500ml);
    }
    return xp > xpRates.waterMaxPerDay ? xpRates.waterMaxPerDay : xp;
  }

  /// Tries to log water. Returns the cap decision so the UI can show
  /// "Max 500 ml per log" or "next log in X min".
  WaterCapResult tryLogWater(int ml) {
    if (demoMode) {
      _blockDemo('logging water');
      final goal = waterHabit.waterGoalMl ?? 5000;
      return WaterCapResult(
        allowed: false,
        maxPerLogMl: goal ~/ 10,
        maxPerHourMl: goal ~/ 5,
        blockedReason:
            'Demo mode is read-only — your log is not saved.',
      );
    }
    final result = canLogWater(
      amountMl: ml,
      dailyGoalMl: waterHabit.waterGoalMl ?? 5000,
      logs: waterToday,
      now: DateTime.now(),
    );
    if (!result.allowed) return result;
    final log = WaterLog(at: DateTime.now(), ml: ml);
    waterLogs.add(log);
    // Water XP is computed from the logs, but the running total needs the
    // new log's XP added now (capped at the daily max).
    final newXp = xpForWaterLog(ml: ml, xpPer500ml: xpRates.waterPer500ml);
    final headroom = xpRates.waterMaxPerDay - (waterXpToday - newXp);
    if (headroom > 0) totalXp += newXp > headroom ? headroom : newXp;
    unawaited(_backend.saveWaterLog(log));
    notifyListeners();
    unawaited(_save());
    return result;
  }

  // ── Planner ───────────────────────────────────────────────────────────────
  Future<ParsedPlan> parsePlanText(String text) => _planner.parse(text);

  /// Returns false when the plan was NOT saved (demo mode).
  bool confirmPlan(WeeklyPlan newPlan) {
    if (demoMode) {
      _blockDemo('confirming a plan');
      return false;
    }
    plan = newPlan;
    // Apply the confirmed habits to the Today list.
    for (final planned in newPlan.habits) {
      final index = habits.indexWhere((h) => h.id == planned.habitId);
      if (index >= 0) {
        habits[index] = habits[index].copyWith(
          targetMinutes: planned.durationMinutes > 0
              ? planned.durationMinutes
              : habits[index].targetMinutes,
          windowStart: planned.windowStart,
          windowEnd: planned.windowEnd,
          preferredStart: planned.preferredStart,
          frequencyPerWeek: planned.frequencyPerWeek,
        );
      }
    }
    unawaited(_backend.savePlan(newPlan));
    notifyListeners();
    unawaited(_save());
    return true;
  }

  // ── Screen time ───────────────────────────────────────────────────────────
  Future<void> refreshUsage() async {
    usagePermissionGranted = await _screenTime.hasUsagePermission();
    final real = await _screenTime.fetchTodayUsage();
    if (real != null && real.isNotEmpty) {
      // Keep the user's tags and limits from the previous list.
      for (final entry in real) {
        final old = _usageByPackage(entry.packageName);
        if (old != null) {
          final index = real.indexOf(entry);
          real[index] = entry.copyWith(
            tag: old.tag,
            dailyLimitMinutes: old.dailyLimitMinutes,
          );
        }
      }
      usage = real;
      usageIsDemo = false;
    } else {
      // Demo data stays, clearly labelled in the UI.
      if (usage.isEmpty) usage = demoUsage();
      usageIsDemo = true;
    }
    _checkSpikePrompt();
    notifyListeners();
    unawaited(_save());
  }

  Future<void> requestUsagePermission() async {
    await _screenTime.openUsageSettings();
  }

  AppUsageEntry? _usageByPackage(String packageName) {
    for (final entry in usage) {
      if (entry.packageName == packageName) return entry;
    }
    return null;
  }

  void setUsageTag(String packageName, UsageTag tag) {
    if (demoMode) {
      _blockDemo('changing an app tag');
      return;
    }
    final index =
        usage.indexWhere((e) => e.packageName == packageName);
    if (index < 0) return;
    usage[index] = usage[index].copyWith(tag: tag);
    if (spikePromptApp?.packageName == packageName) spikePromptApp = null;
    notifyListeners();
    unawaited(_save());
  }

  void setAppLimit(String packageName, int? limitMinutes) {
    if (demoMode) {
      _blockDemo('changing an app limit');
      return;
    }
    final index =
        usage.indexWhere((e) => e.packageName == packageName);
    if (index < 0) return;
    usage[index] = usage[index].copyWith(dailyLimitMinutes: limitMinutes);
    notifyListeners();
    unawaited(_save());
  }

  void _checkSpikePrompt() {
    for (final entry in usage) {
      if (shouldAskAboutSpike(entry)) {
        spikePromptApp = entry;
        return;
      }
    }
  }

  // ── Recap / progress ──────────────────────────────────────────────────────
  List<DaySummary> get last7DaySummaries {
    final days = <DaySummary>[];
    final now = DateTime.now();
    for (var i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      final daySessions =
          sessions.where((s) => s.date == key).toList();
      final done =
          daySessions.where((s) => s.completed).map((s) => s.habitId).toSet();
      final missed = habits
          .where((h) => h.kind != HabitKind.log && !done.contains(h.id))
          .map((h) => h.id)
          .toList();
      final utilised = daySessions.fold<int>(
        0,
        (sum, s) => sum + s.elapsedSeconds ~/ 60,
      );
      final wasted = missed.fold<int>(
            0,
            (sum, id) =>
                sum +
                (habits
                    .firstWhere((h) => h.id == id)
                    .targetMinutes),
          ) +
          usage.fold<int>(0, (sum, u) => sum + u.minutesOverLimit);
      days.add(DaySummary(
        date: key,
        doneHabitIds: done.toList(),
        missedHabitIds: missed,
        xpEarned: daySessions.fold<int>(0, (sum, s) => sum + s.xpEarned),
        waterMl: waterLogs
            .where((w) => _dateKey(w.at) == key)
            .fold<int>(0, (sum, w) => sum + w.ml),
        wastedMinutes: wasted,
        utilisedMinutes: utilised,
      ));
    }
    return days;
  }

  String get endOfDayRecap {
    final days = last7DaySummaries;
    if (days.length < 2) return 'Complete a habit to see your recap here.';
    final names = {for (final h in habits) h.id: h.name};
    return buildEndOfDayRecap(
      today: days.last,
      yesterday: days[days.length - 2],
      habitNames: names,
    );
  }

  int get wastedMinutesToday {
    if (last7DaySummaries.isEmpty) return 0;
    return last7DaySummaries.last.wastedMinutes;
  }

  String get realityCheck =>
      realityCheckProjection(wastedMinutesPerDay: wastedMinutesToday);

  // ── Leaderboard / chat ────────────────────────────────────────────────────
  List<LeaderboardEntry> get leaderboard =>
      demoLeaderboard('You', totalXp);

  /// Global scope: different (demo) players, with You ranked by real XP.
  /// Both scopes are demo data until Firebase provides real rankings.
  List<LeaderboardEntry> get globalLeaderboard {
    final entries = [
      LeaderboardEntry(name: 'ShadowFox', xp: 2480),
      LeaderboardEntry(name: 'IronWill', xp: 1960),
      LeaderboardEntry(name: 'Nova', xp: 1540),
      LeaderboardEntry(name: 'You', xp: totalXp, isYou: true),
      LeaderboardEntry(name: 'Pixel', xp: 980),
      LeaderboardEntry(name: 'Atlas', xp: 640),
    ];
    entries.sort((a, b) => b.xp.compareTo(a.xp));
    return entries;
  }

  /// Returns false when the message was NOT sent (empty, or demo mode).
  Future<bool> sendChatMessage(String text) async {
    if (text.trim().isEmpty) return false;
    if (demoMode) {
      _blockDemo('sending a chat message');
      return false;
    }
    final message = ChatMessage(
      author: 'You',
      text: text.trim(),
      at: DateTime.now(),
      isYou: true,
    );
    chatMessages.add(message);
    await _backend.sendMessage('gym-crew', message);
    notifyListeners();
    unawaited(_save());
    return true;
  }

  // ── Settings ──────────────────────────────────────────────────────────────
  void toggleTheme() {
    isDarkMode = !isDarkMode;
    notifyListeners();
    unawaited(_save());
  }

  void updateXpRates(XpRates rates) {
    if (demoMode) {
      _blockDemo('changing XP rates');
      return;
    }
    xpRates = rates;
    notifyListeners();
    unawaited(_save());
  }

  Future<void> resetAllData() async {
    if (demoMode) {
      _blockDemo('resetting data');
      return;
    }
    habits = defaultHabits();
    sessions = [];
    waterLogs = [];
    totalXp = 0;
    streakDays = 0;
    plan = null;
    usage = demoUsage();
    usageIsDemo = true;
    chatMessages = demoChatMessages();
    _tick?.cancel();
    timerStatus = TimerStatus.idle;
    activeHabitId = null;
    elapsedSeconds = 0;
    await _store.clear();
    notifyListeners();
  }

  // ── Auth + demo ───────────────────────────────────────────────────────────

  /// Signs in with a local account. On success the email is remembered and
  /// the saved data loads. Returns the auth error, if any.
  Future<AuthResult> signIn(String email, String password) async {
    final result = await _auth.signIn(email, password);
    if (result.ok) {
      signedInEmail = email.trim().toLowerCase();
      demoMode = false;
      notifyListeners();
    }
    return result;
  }

  /// Creates a local account and signs in.
  Future<AuthResult> signUp(String email, String password) async {
    final result = await _auth.signUp(email, password);
    if (result.ok) {
      signedInEmail = email.trim().toLowerCase();
      demoMode = false;
      notifyListeners();
    }
    return result;
  }

  /// Signs out: the session token is deleted from secure storage and the
  /// in-memory state is cleared back to a fresh start.
  Future<void> signOut() async {
    await _auth.signOut();
    signedInEmail = null;
    demoMode = false;
    habits = defaultHabits();
    sessions = [];
    waterLogs = [];
    totalXp = 0;
    streakDays = 0;
    plan = null;
    usage = demoUsage();
    usageIsDemo = true;
    chatMessages = demoChatMessages();
    _tick?.cancel();
    timerStatus = TimerStatus.idle;
    activeHabitId = null;
    elapsedSeconds = 0;
    notifyListeners();
  }

  /// Enters Demo Mode: the full app, with sample data, no account, and
  /// READ-ONLY. Nothing here is saved (see _save's demo guard), and every
  /// mutating method refuses while [demoMode] is true — so a demo visitor
  /// can look at everything and try the timer, but cannot change any real
  /// data, by construction, not by hidden buttons.
  void enterDemo() {
    demoMode = true;
    signedInEmail = null;
    demoBlockedMessage = null;
    _seedDemoData();
    notifyListeners();
  }

  /// Leaves demo mode (back to the login screen).
  void exitDemo() {
    demoMode = false;
    _tick?.cancel();
    timerStatus = TimerStatus.idle;
    activeHabitId = null;
    elapsedSeconds = 0;
    notifyListeners();
  }

  /// Sample data for the demo: a believable week, clearly not anyone's real
  /// data. All of it is in-memory only and is discarded on exit.
  void _seedDemoData() {
    final now = DateTime.now();
    String key(DateTime d) => _dateKey(d);
    sessions = [];
    // Last 7 days: gym 60 min on 5 days, study 60 min on 4, wake/sleep
    // check-ins most days — the week the mockup shows.
    for (var i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      if (i % 2 == 0 || i == 1) {
        sessions.add(HabitSession(
          habitId: 'gym',
          date: key(date),
          elapsedSeconds: 3600,
          xpEarned: 80,
          mood: 'Great 😄',
          completed: true,
        ));
      }
      if (i % 3 != 0) {
        sessions.add(HabitSession(
          habitId: 'study',
          date: key(date),
          elapsedSeconds: 3600,
          xpEarned: 100,
          mood: 'Okay 🙂',
          completed: true,
        ));
      }
      sessions.add(HabitSession(
        habitId: 'wake',
        date: key(date),
        elapsedSeconds: 0,
        xpEarned: 40,
        completed: true,
      ));
      if (i % 4 != 0) {
        sessions.add(HabitSession(
          habitId: 'sleep',
          date: key(date),
          elapsedSeconds: 0,
          xpEarned: 40,
          completed: true,
        ));
      }
    }
    // Water today: 4L in 500 ml logs (the cap makes 500 ml the max log).
    waterLogs = List.generate(
      8,
      (i) => WaterLog(
        at: now.subtract(Duration(hours: 10 - i)),
        ml: 500,
      ),
    );
    // Total XP is always the sum of what the seeded sessions + water
    // actually earned — never a made-up number.
    totalXp = sessions.fold<int>(0, (sum, s) => sum + s.xpEarned) +
        waterLogs.fold<int>(
          0,
          (sum, w) =>
              sum + xpForWaterLog(ml: w.ml, xpPer500ml: xpRates.waterPer500ml),
        ).clamp(0, xpRates.waterMaxPerDay);
    plan = WeeklyPlan(
      text: 'Gym three times a week for one hour, 4 PM to 5 PM, '
          'keep the slot 4 to 6, and drink 5 litres of water every day.',
      habits: [
        PlannedHabit(
          habitId: 'gym',
          name: 'Gym',
          frequencyPerWeek: 3,
          durationMinutes: 60,
          windowStart: '16:00',
          windowEnd: '18:00',
          preferredStart: '16:00',
        ),
        PlannedHabit(
          habitId: 'water',
          name: 'Drink water',
          frequencyPerWeek: 7,
          durationMinutes: 0,
          windowStart: '07:00',
          windowEnd: '22:00',
          preferredStart: '07:00',
          waterGoalMl: 5000,
        ),
      ],
      createdAt: now.subtract(const Duration(days: 2)),
    );
    usage = demoUsage();
    usageIsDemo = true;
    chatMessages = demoChatMessages();
    _recomputeStreak();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _recomputeStreak() {
    final completedDates = sessions
        .where((s) => s.completed)
        .map((s) => s.date)
        .toSet();
    var streak = 0;
    var cursor = DateTime.now();
    // A streak counts back from today (or yesterday if today is not done
    // yet — the day is not over).
    if (!completedDates.contains(_dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (completedDates.contains(_dateKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    streakDays = streak;
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _todayKey() => _dateKey(DateTime.now());

  @override
  void dispose() {
    _tick?.cancel();
    _focusLock.dispose();
    super.dispose();
  }
}
