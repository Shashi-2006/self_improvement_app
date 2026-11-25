// SETTINGS — theme, XP rates (owner-editable), and danger zone.
//
// "XP by task, owner decides" lives here: the owner edits the rates and
// they apply immediately to every new session.

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final rates = state.xpRates;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const SectionTitle('Appearance'),
        AppCard(
          child: SwitchListTile(
            title: const Text('Dark mode'),
            subtitle: const Text('Light and dark, your choice.'),
            value: state.isDarkMode,
            onChanged: (_) => state.toggleTheme(),
            secondary: Icon(
              state.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: AppTheme.amber,
            ),
          ),
        ),
        const SectionTitle('XP rates — owner decides'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You are the app owner. These rates apply to every new '
                'session. XP stays proportional — half the time, half the XP.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              _RateEditor(
                label: 'Study (per hour)',
                value: rates.studyPerHour,
                onChanged: (v) =>
                    state.updateXpRates(rates.copyWith(studyPerHour: v)),
              ),
              _RateEditor(
                label: 'Gym (per hour)',
                value: rates.gymPerHour,
                onChanged: (v) =>
                    state.updateXpRates(rates.copyWith(gymPerHour: v)),
              ),
              _RateEditor(
                label: 'Wake up early (per day)',
                value: rates.wakePerDay,
                onChanged: (v) =>
                    state.updateXpRates(rates.copyWith(wakePerDay: v)),
              ),
              _RateEditor(
                label: 'Sleep on time (per day)',
                value: rates.sleepPerDay,
                onChanged: (v) =>
                    state.updateXpRates(rates.copyWith(sleepPerDay: v)),
              ),
              _RateEditor(
                label: 'Water (per 500 ml)',
                value: rates.waterPer500ml,
                onChanged: (v) =>
                    state.updateXpRates(rates.copyWith(waterPer500ml: v)),
              ),
              _RateEditor(
                label: 'Water max (per day)',
                value: rates.waterMaxPerDay,
                onChanged: (v) =>
                    state.updateXpRates(rates.copyWith(waterMaxPerDay: v)),
              ),
            ],
          ),
        ),
        const SectionTitle('About this build'),
        const AppCard(
          child: Text(
            'Self-Improvement App v1.0.0 — Full v1.\n\n'
            'Local-first: everything works offline. Leaderboard and chat '
            'use demo data until Firebase is connected (see README and '
            'docs/firebase-setup.md).\n\n'
            'Screen time and focus lock use real Android APIs when Usage '
            'Access is granted; on web they show clearly-labelled demo data.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        const SectionTitle('Danger zone'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Deletes all habits, sessions, water logs and XP.'),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reset everything?'),
                      content: const Text(
                        'This deletes all your local data. There is no undo.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await state.resetAllData();
                  }
                },
                icon: const Icon(Icons.delete_forever, color: AppTheme.rose),
                label: const Text(
                  'Reset all data',
                  style: TextStyle(color: AppTheme.rose),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RateEditor extends StatelessWidget {
  const _RateEditor({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            onPressed: value > 0 ? () => onChanged(value - 5) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + 5),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
