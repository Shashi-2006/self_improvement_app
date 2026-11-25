import 'package:flutter_test/flutter_test.dart';
import 'package:self_improvement_app/models/app_models.dart';
import 'package:self_improvement_app/services/water_cap.dart';

void main() {
  final now = DateTime(2026, 11, 25, 10, 0);

  group('water cap — 5L goal', () {
    test('500 ml log is allowed (10% of goal)', () {
      final result = canLogWater(
        amountMl: 500,
        dailyGoalMl: 5000,
        logs: const [],
        now: now,
      );
      expect(result.allowed, true);
      expect(result.maxPerLogMl, 500);
      expect(result.maxPerHourMl, 1000);
    });

    test('1250 ml in one log is blocked — over the 1 L/hour kidney limit', () {
      final result = canLogWater(
        amountMl: 1250,
        dailyGoalMl: 5000,
        logs: const [],
        now: now,
      );
      expect(result.allowed, false);
      expect(result.blockedReason, contains('500 ml per log'));
    });

    test('second 500 ml within the hour is allowed (1000 ml/hour cap)', () {
      final result = canLogWater(
        amountMl: 500,
        dailyGoalMl: 5000,
        logs: [WaterLog(at: now.subtract(const Duration(minutes: 30)), ml: 500)],
        now: now,
      );
      expect(result.allowed, true);
    });

    test('third 500 ml within the hour is blocked with a cooldown', () {
      final result = canLogWater(
        amountMl: 500,
        dailyGoalMl: 5000,
        logs: [
          WaterLog(at: now.subtract(const Duration(minutes: 50)), ml: 500),
          WaterLog(at: now.subtract(const Duration(minutes: 20)), ml: 500),
        ],
        now: now,
      );
      expect(result.allowed, false);
      expect(result.nextLogIn, isNotNull);
      // Oldest log was 50 min ago: next log in ~10 min.
      expect(result.nextLogIn!.inMinutes, 10);
    });

    test('old logs slide out of the window — logging works again', () {
      final result = canLogWater(
        amountMl: 500,
        dailyGoalMl: 5000,
        logs: [
          WaterLog(at: now.subtract(const Duration(hours: 2)), ml: 500),
          WaterLog(at: now.subtract(const Duration(hours: 3)), ml: 500),
        ],
        now: now,
      );
      expect(result.allowed, true);
    });

    test('cap scales with the goal: 3L goal means 300 ml per log', () {
      final result = canLogWater(
        amountMl: 500,
        dailyGoalMl: 3000,
        logs: const [],
        now: now,
      );
      expect(result.allowed, false);
      expect(result.maxPerLogMl, 300);
    });
  });

  group('waterRemainingMl', () {
    test('5L goal minus 1.5L drunk leaves 3.5L', () {
      expect(
        waterRemainingMl(
          dailyGoalMl: 5000,
          logs: [
            WaterLog(at: now, ml: 1000),
            WaterLog(at: now, ml: 500),
          ],
        ),
        3500,
      );
    });
  });
}
