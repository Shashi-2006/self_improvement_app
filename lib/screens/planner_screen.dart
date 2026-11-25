// PLAN — the AI weekly planner.
//
// FLOW (from the spec):
//  1. The user describes the week in plain words.
//  2. The planner parses it into a structured plan and shows it back:
//     "Is this what you meant?"
//  3. The user edits timings, dates and frequency inline, right there.
//  4. Confirm schedules it for the week.
//
// v1 uses the on-device rule-based parser (no API key, works offline).
// A real LLM can be plugged in later — see plan_parser.dart.

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/plan_parser.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, required this.state});

  final AppState state;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _textController = TextEditingController(
    text: 'I want to go gym three times a week for one hour, '
        'gym timing 4 PM to 5 PM, keep the slot 4 to 6, '
        'and drink 5 litres of water every day.',
  );
  ParsedPlan? _parsed;
  List<PlannedHabit> _editable = [];
  bool _parsing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    setState(() => _parsing = true);
    final parsed =
        await widget.state.parsePlanText(_textController.text);
    setState(() {
      _parsed = parsed;
      _editable = List<PlannedHabit>.from(parsed.habits);
      _parsing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.state.plan;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text(
          'Describe your week in plain words. I\'ll turn it into a plan '
          'and show it back — you edit anything before confirming.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'e.g. gym 3 times a week for 1 hour, 4 to 5 pm, '
                'and drink 5 litres of water every day',
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _parsing ? null : _parse,
          icon: _parsing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_parsing ? 'Reading…' : 'Make my plan'),
        ),
        if (_parsed != null) ...[
          const SectionTitle('Is this what you meant?'),
          for (var i = 0; i < _editable.length; i++)
            _EditablePlanRow(
              habit: _editable[i],
              onChanged: (updated) {
                setState(() => _editable[i] = updated);
              },
            ),
          for (final note in _parsed!.unparsedNotes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Note: $note',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              final saved = widget.state.confirmPlan(
                WeeklyPlan(
                  text: _textController.text,
                  habits: _editable,
                  createdAt: DateTime.now(),
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    saved
                        ? 'Plan confirmed for this week.'
                        : widget.state.demoBlockedMessage ??
                            'Plan not saved.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('Yes — confirm this plan'),
          ),
        ],
        if (plan != null) ...[
          const SectionTitle('Your current plan'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${plan.text}"',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 10),
                for (final habit in plan.habits)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(habit.name),
                        Text(
                          habit.waterGoalMl != null
                              ? '${habit.waterGoalMl! ~/ 1000}L daily'
                              : '${habit.frequencyPerWeek}x/week · '
                                  '${habit.durationMinutes} min · '
                                  '${habit.preferredStart}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const AppCard(
          child: Text(
            'How it works: v1 parses your words on the device — no account, '
            'no API key, works offline. A real AI can be plugged in later '
            'at one point in the code (see lib/services/plan_parser.dart); '
            'the confirm-and-edit screen stays the same either way.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// One planned habit with inline editors: frequency stepper, duration
/// stepper, and time fields the user can tap and change.
class _EditablePlanRow extends StatelessWidget {
  const _EditablePlanRow({required this.habit, required this.onChanged});

  final PlannedHabit habit;
  final ValueChanged<PlannedHabit> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  habit.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                XpChip(
                  habit.waterGoalMl != null
                      ? '${habit.waterGoalMl! ~/ 1000}L / day'
                      : '${habit.durationMinutes} min',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Times per week: '),
                IconButton(
                  onPressed: habit.frequencyPerWeek > 1
                      ? () => onChanged(
                            habit.copyWith(
                              frequencyPerWeek: habit.frequencyPerWeek - 1,
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '${habit.frequencyPerWeek}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: habit.frequencyPerWeek < 7
                      ? () => onChanged(
                            habit.copyWith(
                              frequencyPerWeek: habit.frequencyPerWeek + 1,
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const Spacer(),
                if (habit.durationMinutes > 0) ...[
                  const Text('Minutes: '),
                  IconButton(
                    onPressed: habit.durationMinutes > 10
                        ? () => onChanged(
                              habit.copyWith(
                                durationMinutes: habit.durationMinutes - 10,
                              ),
                            )
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '${habit.durationMinutes}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => onChanged(
                      habit.copyWith(
                        durationMinutes: habit.durationMinutes + 10,
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Preferred start',
                    value: habit.preferredStart,
                    onChanged: (v) =>
                        onChanged(habit.copyWith(preferredStart: v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeField(
                    label: 'Window end',
                    value: habit.windowEnd,
                    onChanged: (v) =>
                        onChanged(habit.copyWith(windowEnd: v)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.datetime,
      onChanged: (text) {
        // Accept "HH:MM" only; anything else is ignored until it is valid.
        if (RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$').hasMatch(text.trim())) {
          final parts = text.trim().split(':');
          onChanged(
            '${parts[0].padLeft(2, '0')}:${parts[1]}',
          );
        }
      },
    );
  }
}
