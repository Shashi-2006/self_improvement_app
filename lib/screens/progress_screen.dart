// PROGRESS — end-of-day recap, weekly utilised-vs-wasted chart, screen
// time, and the weekly orbit recap.
//
// When the user has no real data yet, the chart shows a clearly-labelled
// SAMPLE week (the numbers from the mockup) so the screen is not empty —
// real sessions replace it as soon as they exist.

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/recap_service.dart';
import '../services/screen_time_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/orbit_recap.dart';
import '../widgets/weekly_chart.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.state});

  final AppState state;

  /// Sample week (from the mockup) shown only until real data exists.
  List<DaySummary> _sampleWeek() {
    final now = DateTime.now();
    final utilised = [45, 60, 30, 60, 0, 50, 60];
    final wasted = [120, 90, 150, 100, 180, 110, 95];
    return List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return DaySummary(
        date: key,
        doneHabitIds: utilised[i] > 0 ? ['gym'] : [],
        missedHabitIds: utilised[i] == 0 ? ['gym', 'study'] : ['study'],
        xpEarned: utilised[i],
        waterMl: 4000,
        wastedMinutes: wasted[i],
        utilisedMinutes: utilised[i],
      );
    });
  }

  bool get _hasRealData =>
      state.sessions.isNotEmpty || state.waterLogs.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final days = _hasRealData ? state.last7DaySummaries : _sampleWeek();
    final totals = weeklyTotals(days);
    final wasting = topWastingApps(state.usage);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── End-of-day recap ──────────────────────────────────────────────
        const SectionTitle('End-of-day recap'),
        AppCard(
          child: Text(
            _hasRealData
                ? state.endOfDayRecap
                : 'Sample recap: you were good today — gym done, 4L water. '
                    'You missed study today. Keep it up tomorrow.',
          ),
        ),

        // ── Weekly chart ──────────────────────────────────────────────────
        SectionTitle(
          'This week — utilised vs wasted',
          action: _hasRealData
              ? null
              : const Chip(label: Text('Sample data'), visualDensity: VisualDensity.compact),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WeeklyChart(days: days),
              const SizedBox(height: 12),
              Text(
                'Utilised ${formatMinutes(totals.utilisedMinutes)} · '
                'wasted ${formatMinutes(totals.wastedMinutes)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                state.realityCheck,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),

        // ── Screen time ───────────────────────────────────────────────────
        SectionTitle(
          'Your top time today',
          action: state.usageIsDemo
              ? const Chip(label: Text('Demo data'), visualDensity: VisualDensity.compact)
              : const Chip(label: Text('From your phone'), visualDensity: VisualDensity.compact),
        ),
        if (!state.usageIsDemo || state.usagePermissionGranted)
          const SizedBox.shrink()
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Real numbers need Usage Access permission. '
                    'Until then you are seeing demo data.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: state.requestUsagePermission,
                    child: const Text('Grant Usage Access'),
                  ),
                ],
              ),
            ),
          ),
        for (final app in state.usage) _UsageRow(state: state, app: app),

        // ── Orbit recap ───────────────────────────────────────────────────
        const SectionTitle('Weekly orbit recap'),
        OrbitRecap(apps: wasting, realityCheck: state.realityCheck),
      ],
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.state, required this.app});

  final AppState state;
  final AppUsageEntry app;

  @override
  Widget build(BuildContext context) {
    final tagLabel = switch (app.tag) {
      UsageTag.productive => 'Productive',
      UsageTag.nonProductive => 'Non-productive',
      UsageTag.unclassified => 'You decide',
    };
    final tagColor = switch (app.tag) {
      UsageTag.productive => AppTheme.emerald,
      UsageTag.nonProductive => AppTheme.rose,
      UsageTag.unclassified => AppTheme.amber,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: appColour(app.appName),
                  foregroundColor: Colors.white,
                  child: Text(
                    app.appName[0],
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.appName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${formatMinutes(app.minutesToday)} today'
                        '${app.dailyLimitMinutes != null ? ' · limit ${formatMinutes(app.dailyLimitMinutes!)}' : ''}'
                        '${app.minutesOverLimit > 0 ? ' · ${formatMinutes(app.minutesOverLimit)} over' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tagLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tagColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Tag: ', style: TextStyle(fontSize: 12)),
                _TagButton(
                  label: 'Productive',
                  selected: app.tag == UsageTag.productive,
                  onTap: () =>
                      state.setUsageTag(app.packageName, UsageTag.productive),
                ),
                const SizedBox(width: 6),
                _TagButton(
                  label: 'Non-productive',
                  selected: app.tag == UsageTag.nonProductive,
                  onTap: () => state.setUsageTag(
                    app.packageName,
                    UsageTag.nonProductive,
                  ),
                ),
                const SizedBox(width: 6),
                _TagButton(
                  label: 'Undecided',
                  selected: app.tag == UsageTag.unclassified,
                  onTap: () => state.setUsageTag(
                    app.packageName,
                    UsageTag.unclassified,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<int?>(
                  tooltip: 'Daily limit',
                  icon: const Icon(Icons.timer_outlined, size: 20),
                  onSelected: (limit) =>
                      state.setAppLimit(app.packageName, limit),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: null, child: Text('No limit')),
                    const PopupMenuItem(value: 30, child: Text('30 min/day')),
                    const PopupMenuItem(value: 60, child: Text('1 h/day')),
                    const PopupMenuItem(value: 120, child: Text('2 h/day')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagButton extends StatelessWidget {
  const _TagButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
