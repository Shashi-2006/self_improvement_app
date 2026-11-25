import 'package:flutter_test/flutter_test.dart';
import 'package:self_improvement_app/services/plan_parser.dart';

void main() {
  final planner = RuleBasedPlanner();

  test('the spec example: gym 3x/week 1h 4-5pm in a 4-6 slot, 5L water daily', () async {
    final plan = await planner.parse(
      'I want to go gym three times a week for one hour, '
      'gym timing 4 PM to 5 PM, keep the slot 4 to 6, '
      'and drink 5 litres of water every day.',
    );
    final gym = plan.habits.firstWhere((h) => h.habitId == 'gym');
    expect(gym.frequencyPerWeek, 3);
    expect(gym.durationMinutes, 60);
    expect(gym.preferredStart, '16:00');
    final water = plan.habits.firstWhere((h) => h.habitId == 'water');
    expect(water.frequencyPerWeek, 7);
    expect(water.waterGoalMl, 5000);
  });

  test('digits work too: gym 3x/week, 90 minutes', () async {
    final plan = await planner.parse('gym 3x a week for 90 minutes at 6 am');
    final gym = plan.habits.firstWhere((h) => h.habitId == 'gym');
    expect(gym.frequencyPerWeek, 3);
    expect(gym.durationMinutes, 90);
    expect(gym.preferredStart, '06:00');
  });

  test('study and wake-up are picked up', () async {
    final plan = await planner.parse('study 1 hour daily and wake up early');
    expect(plan.habits.map((h) => h.habitId), containsAll(['study', 'wake']));
    final study = plan.habits.firstWhere((h) => h.habitId == 'study');
    expect(study.durationMinutes, 60);
    expect(study.frequencyPerWeek, 7);
  });

  test('unknown text returns no habits and an honest note', () async {
    final plan = await planner.parse('do something amazing this week');
    expect(plan.habits, isEmpty);
    expect(plan.unparsedNotes, isNotEmpty);
  });
}
