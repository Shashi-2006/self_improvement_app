import 'package:flutter_test/flutter_test.dart';
import 'package:self_improvement_app/services/xp_calculator.dart';

void main() {
  group('xpForSession — proportional XP', () {
    test('full hour earns full XP', () {
      expect(xpForSession(elapsedSeconds: 3600, targetSeconds: 3600, fullXp: 80), 80);
    });

    test('half the time earns half the XP', () {
      expect(xpForSession(elapsedSeconds: 1800, targetSeconds: 3600, fullXp: 80), 40);
      expect(xpForSession(elapsedSeconds: 1800, targetSeconds: 3600, fullXp: 100), 50);
    });

    test('5 minutes of 60 does NOT earn full XP', () {
      expect(xpForSession(elapsedSeconds: 300, targetSeconds: 3600, fullXp: 100), 8);
    });

    test('zero-time rule: 0:00 = 0 XP', () {
      expect(xpForSession(elapsedSeconds: 0, targetSeconds: 3600, fullXp: 100), 0);
    });

    test('overtime is capped at full XP', () {
      expect(xpForSession(elapsedSeconds: 4000, targetSeconds: 3600, fullXp: 80), 80);
    });
  });

  group('xpForWaterLog', () {
    test('500 ml earns the full per-log rate', () {
      expect(xpForWaterLog(ml: 500, xpPer500ml: 10), 10);
    });

    test('250 ml earns half', () {
      expect(xpForWaterLog(ml: 250, xpPer500ml: 10), 5);
    });

    test('0 ml earns 0', () {
      expect(xpForWaterLog(ml: 0, xpPer500ml: 10), 0);
    });
  });

  group('levelFor', () {
    test('0 XP is level 1, 0 into the level', () {
      final l = levelFor(0);
      expect((l.level, l.xpIntoLevel, l.xpForNextLevel), (1, 0, 100));
    });

    test('100 XP reaches level 2', () {
      final l = levelFor(100);
      expect((l.level, l.xpIntoLevel), (2, 0));
    });

    test('250 XP is level 2 with 150 into it (needs 200 for level 3)', () {
      final l = levelFor(250);
      expect((l.level, l.xpIntoLevel, l.xpForNextLevel), (2, 150, 200));
    });
  });

  group('XpRates defaults', () {
    test('matches the spec: study 100, gym 80, wake/sleep 40, water 10/50', () {
      const rates = XpRates();
      expect(rates.studyPerHour, 100);
      expect(rates.gymPerHour, 80);
      expect(rates.wakePerDay, 40);
      expect(rates.sleepPerDay, 40);
      expect(rates.waterPer500ml, 10);
      expect(rates.waterMaxPerDay, 50);
      expect(rates.perHourFor('study'), 100);
      expect(rates.perDayFor('wake'), 40);
    });
  });
}
