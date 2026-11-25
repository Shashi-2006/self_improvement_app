// TODAY — the home screen. Habits due now, the timer, water, streaks.
//
// The screen listens to AppState (via AnimatedBuilder in main.dart) and
// rebuilds whenever the state changes — e.g. every second while the timer
// ticks. It never holds timer data itself; AppState owns it.

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/xp_calculator.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final level = levelFor(state.totalXp);
    final waterHabit = state.waterHabit;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── Header: level, XP, streak ─────────────────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level ${level.level}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        '${state.totalXp} XP total',
                        style: const TextStyle(color: AppTheme.amber),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: AppTheme.amber,
                          ),
                          Text(
                            '${state.streakDays}-day streak',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${level.xpIntoLevel} / ${level.xpForNextLevel} XP to level ${level.level + 1}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ThinProgress(
                value: level.xpIntoLevel / level.xpForNextLevel,
                color: AppTheme.amber,
              ),
            ],
          ),
        ),

        // ── Focus-lock bounce banner ──────────────────────────────────────
        if (state.focusBlockedMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.roseSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock, color: AppTheme.rose),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.focusBlockedMessage!,
                    style: const TextStyle(
                      color: AppTheme.rose,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Active timer (or the habit list) ──────────────────────────────
        if (state.timerStatus != TimerStatus.idle &&
            state.activeHabit != null)
          _ActiveTimerCard(state: state, habit: state.activeHabit!)
        else ...[
          const SectionTitle('Today\'s habits'),
          for (final habit in state.habits) _HabitCard(state: state, habit: habit),
        ],

        // ── Water ─────────────────────────────────────────────────────────
        const SectionTitle('Water'),
        _WaterCard(state: state, habit: waterHabit),

        // ── Spike prompt ──────────────────────────────────────────────────
        if (state.spikePromptApp != null) ...[
          const SectionTitle('Quick question'),
          _SpikePromptCard(state: state, app: state.spikePromptApp!),
        ],
      ],
    );
  }
}

// ── One habit card ───────────────────────────────────────────────────────────

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.state, required this.habit});

  final AppState state;
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final doneToday = habit.kind == HabitKind.checkIn
        ? state.checkInToday(habit.id)
        : state.sessions.any(
            (s) =>
                s.habitId == habit.id &&
                s.completed &&
                s.date ==
                    '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
          );
    final xpLabel = switch (habit.kind) {
      HabitKind.timer =>
        '${state.xpRates.perHourFor(habit.id)} XP / hour',
      HabitKind.checkIn =>
        '${state.xpRates.perDayFor(habit.id)} XP / day',
      HabitKind.log =>
        '${state.xpRates.waterPer500ml} XP / 500 ml',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(habit.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        habit.kind == HabitKind.timer
                            ? 'Window ${_prettyTime(habit.windowStart)}–${_prettyTime(habit.windowEnd)}'
                                ' · ${habit.targetMinutes} min · ${habit.frequencyPerWeek}x/week'
                            : habit.kind == HabitKind.checkIn
                                ? 'One check-in a day'
                                : 'Goal ${habit.waterGoalMl! ~/ 1000}L a day',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                XpChip(xpLabel),
              ],
            ),
            const SizedBox(height: 12),
            if (doneToday)
              const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.emerald, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Done today ✓',
                    style: TextStyle(
                      color: AppTheme.emerald,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            else if (habit.kind == HabitKind.timer)
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Are you doing it today?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _askFocusLock(context, habit),
                    child: const Text('Start timer'),
                  ),
                ],
              )
            else if (habit.kind == HabitKind.checkIn)
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Done? Tap to check in.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final saved = state.checkIn(habit.id);
                      if (!saved && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              state.demoBlockedMessage ??
                                  'Already checked in today.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Check in'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// The focus-lock question, asked BEFORE the timer starts (spec §2a).
  Future<void> _askFocusLock(BuildContext context, Habit habit) async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Focus lock'),
        content: const Text(
          'Do you want unproductive apps on or off during this session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('On — allow them'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Off — block them'),
          ),
        ],
      ),
    );
    if (choice == null) return; // dismissed — don't start the timer
    // choice == false means "off" (block them); true means "on" (allow).
    // focusLockOn is true when apps are OFF.
    state.startTimer(habit, focusLockChoice: !choice);
  }

  String _prettyTime(String hhmm) {
    final parts = hhmm.split(':');
    var hour = int.parse(parts[0]);
    final minute = parts[1];
    final ampm = hour >= 12 ? 'pm' : 'am';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return minute == '00' ? '$hour$ampm' : '$hour:$minute$ampm';
  }
}

// ── The running / paused timer ───────────────────────────────────────────────

class _ActiveTimerCard extends StatelessWidget {
  const _ActiveTimerCard({required this.state, required this.habit});

  final AppState state;
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final running = state.timerStatus == TimerStatus.running;
    final progress =
        state.elapsedSeconds / (state.activeTargetSeconds == 0
            ? 1
            : state.activeTargetSeconds);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AppCard(
        child: Column(
          children: [
            Row(
              children: [
                Text(habit.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    habit.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (state.focusLockOn)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.roseSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 14, color: AppTheme.rose),
                        SizedBox(width: 4),
                        Text(
                          'Focus lock ON',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.rose,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              formatDuration(state.elapsedSeconds),
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800),
            ),
            Text(
              running ? 'Timer running' : 'Paused — your time is saved',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ThinProgress(value: progress, color: AppTheme.emerald),
            const SizedBox(height: 8),
            Text(
              'Target ${habit.targetMinutes} min · '
              'finishing now earns ${state.currentSessionXp} XP',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: running
                      ? OutlinedButton.icon(
                          onPressed: state.pauseTimer,
                          icon: const Icon(Icons.pause),
                          label: const Text('Pause'),
                        )
                      : ElevatedButton.icon(
                          onPressed: state.resumeTimer,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Resume'),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _finish(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Finish'),
                  ),
                ),
              ],
            ),
            if (state.focusLockOn) ...[
              const SizedBox(height: 12),
              const Text(
                'Unproductive apps are blocked while this timer runs. '
                'Pausing lifts the lock until you resume.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              _BlockedAppsTray(state: state),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _finish(BuildContext context) async {
    // Mood is asked AFTER finishing — and only counts when time was done
    // (the zero-time rule: 0:00 earns 0 XP and no mood bonus).
    final earnedXp = state.currentSessionXp;
    String? mood;
    if (state.elapsedSeconds > 0) {
      mood = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('How did it go?'),
          children: ['Great 😄', 'Okay 🙂', 'Tired 😮‍💨', 'Hard 😓']
              .map(
                (m) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, m),
                  child: Text(m),
                ),
              )
              .toList(),
        ),
      );
    }
    final saved = state.finishTimer(mood: mood);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !saved
                ? state.demoBlockedMessage ??
                    'Demo mode — session not saved.'
                : earnedXp > 0
                    ? 'Nice work! +$earnedXp XP banked.'
                    : 'Stopped at 0:00 — 0 XP, nothing banked.',
          ),
        ),
      );
    }
  }
}

/// The tray of blocked apps under the timer. On a real Android phone the
/// focus lock bounces the user back; here (and on web) tapping one shows the
/// same blocked message as a preview.
class _BlockedAppsTray extends StatelessWidget {
  const _BlockedAppsTray({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final blocked = state.usage
        .where((u) => state.blockedPackages.contains(u.packageName))
        .toList();
    if (blocked.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: blocked
          .map(
            (app) => ActionChip(
              avatar: const Icon(Icons.lock, size: 14),
              label: Text(app.appName),
              onPressed: () {
                final message =
                    '${app.appName} is blocked during this focus session — '
                    'back to your timer (${formatDuration(state.elapsedSeconds)} in).';
                state.showFocusBlockedMessage(message);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              },
            ),
          )
          .toList(),
    );
  }
}

// ── Water ────────────────────────────────────────────────────────────────────

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.state, required this.habit});

  final AppState state;
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final goal = habit.waterGoalMl ?? 5000;
    final drunk = state.waterDrunkTodayMl;
    final remaining = goal - drunk < 0 ? 0 : goal - drunk;
    final maxPerLog = goal ~/ 10;
    final maxPerHour = goal ~/ 5;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(drunk / 1000).toStringAsFixed(1)}L / ${(goal / 1000).toStringAsFixed(0)}L',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              XpChip('${state.waterXpToday} XP today'),
            ],
          ),
          const SizedBox(height: 8),
          ThinProgress(value: drunk / goal, color: AppTheme.sky),
          const SizedBox(height: 6),
          Text(
            remaining > 0
                ? '${(remaining / 1000).toStringAsFixed(1)}L left today'
                : 'Goal reached — great hydration!',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [100, 250, 500].map((ml) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(
                    onPressed: () => _log(context, ml),
                    child: Text('+$ml ml'),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Max $maxPerLog ml per log, max $maxPerHour ml per hour — '
            'spread it out. Kidneys clear about 1 L per hour.',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _log(BuildContext context, int ml) {
    final result = state.tryLogWater(ml);
    final message = result.allowed
        ? '+$ml ml logged.'
        : result.blockedReason ??
            'Could not log that right now.';
    final suffix = result.nextLogIn != null
        ? ' Next log in ${result.nextLogIn!.inMinutes} min.'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$message$suffix')),
    );
  }
}

// ── Spike prompt ─────────────────────────────────────────────────────────────

class _SpikePromptCard extends StatelessWidget {
  const _SpikePromptCard({required this.state, required this.app});

  final AppState state;
  final AppUsageEntry app;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${app.appName} is taking more of your time — '
            '${formatMinutes(app.minutesToday)} today, up from '
            '${formatMinutes(app.minutesYesterday)} yesterday.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (app.isGame)
            const Text('This looks like a game — count it as non-productive?'),
          const SizedBox(height: 4),
          const Text('Is it productive or non-productive for you?'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      state.setUsageTag(app.packageName, UsageTag.productive),
                  child: const Text('Productive'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => state.setUsageTag(
                    app.packageName,
                    UsageTag.nonProductive,
                  ),
                  child: const Text('Non-productive'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
