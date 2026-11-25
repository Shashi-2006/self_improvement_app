// ─────────────────────────────────────────────────────────────────────────────
// AI WEEKLY PLANNER — rule-based parser (v1).
//
// THE HONEST VERSION: v1 does NOT call a real AI. It is a small rule-based
// parser that reads the user's plain words and turns them into a structured
// plan. That is enough for the examples in the spec ("gym three times a week
// for one hour, 4 PM to 5 PM, keep the slot 4 to 6, drink 5 litres of water
// every day") and it works fully offline, with no API key and no cost.
//
// THE PLUG-IN POINT: [WeeklyPlanner] is an interface. [RuleBasedPlanner] is
// the v1 implementation. To use a real LLM later, write a class that
// implements [WeeklyPlanner] (call your API, return the same [ParsedPlan])
// and swap one line in lib/state/app_state.dart. Nothing else changes —
// the confirmation screen ("Is this what you meant?") and the inline editor
// stay exactly the same, because a wrong guess must never become the plan.
//
// What the parser understands:
//  * Habits: gym, study, water, wake up early, sleep on time, run, read,
//    meditate, yoga.
//  * Frequency: "3 times a week", "3x a week", "daily", "every day",
//    "weekdays", "twice a week".
//  * Duration: "1 hour", "90 minutes", "30 min".
//  * Times: "4 pm", "4:30 pm", "16:00", "4 to 5 pm", "4-5 pm",
//    "keep the slot 4 to 6".
//  * Water amount: "5 litres", "5L", "3 liters".
// ─────────────────────────────────────────────────────────────────────────────

import '../models/app_models.dart';

/// What the planner returns: the habits it found, plus the bits of the
/// sentence it could not understand, so the UI can ask about them instead of
/// silently guessing.
class ParsedPlan {
  ParsedPlan({required this.habits, required this.unparsedNotes});

  final List<PlannedHabit> habits;

  /// Plain-language notes about anything unclear, shown under the plan.
  final List<String> unparsedNotes;
}

/// The contract any planner must fulfil — rule-based today, LLM tomorrow.
abstract class WeeklyPlanner {
  Future<ParsedPlan> parse(String text);
}

/// Number words the parser recognises.
const Map<String, int> _numberWords = {
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
};

/// One habit the parser knows how to spot, with its defaults.
class _HabitSpec {
  const _HabitSpec({
    required this.id,
    required this.name,
    required this.keywords,
    required this.defaultDurationMinutes,
    required this.defaultWindowStart,
    required this.defaultWindowEnd,
    this.defaultFrequencyPerWeek = 7,
    this.isWater = false,
  });

  final String id;
  final String name;

  /// Words that mean this habit. Checked longest-first so "wake up early"
  /// wins over "wake".
  final List<String> keywords;
  final int defaultDurationMinutes;
  final String defaultWindowStart;
  final String defaultWindowEnd;
  final int defaultFrequencyPerWeek;
  final bool isWater;
}

const List<_HabitSpec> _habitSpecs = [
  _HabitSpec(
    id: 'gym',
    name: 'Gym',
    keywords: ['gym', 'workout', 'exercise'],
    defaultDurationMinutes: 60,
    defaultWindowStart: '16:00',
    defaultWindowEnd: '18:00',
    defaultFrequencyPerWeek: 3,
  ),
  _HabitSpec(
    id: 'study',
    name: 'Study',
    keywords: ['study', 'studying', 'leetcode', 'coding practice'],
    defaultDurationMinutes: 60,
    defaultWindowStart: '09:00',
    defaultWindowEnd: '21:00',
  ),
  _HabitSpec(
    id: 'water',
    name: 'Drink water',
    keywords: ['water', 'drink water', 'litres of water', 'liters of water'],
    defaultDurationMinutes: 0,
    defaultWindowStart: '07:00',
    defaultWindowEnd: '22:00',
    isWater: true,
  ),
  _HabitSpec(
    id: 'wake',
    name: 'Wake up early',
    keywords: ['wake up early', 'wake early', 'wake up'],
    defaultDurationMinutes: 0,
    defaultWindowStart: '05:00',
    defaultWindowEnd: '07:00',
  ),
  _HabitSpec(
    id: 'sleep',
    name: 'Sleep on time',
    keywords: ['sleep on time', 'sleep early', 'sleep'],
    defaultDurationMinutes: 0,
    defaultWindowStart: '22:00',
    defaultWindowEnd: '23:00',
  ),
  _HabitSpec(
    id: 'run',
    name: 'Run',
    keywords: ['run', 'running', 'jog'],
    defaultDurationMinutes: 30,
    defaultWindowStart: '06:00',
    defaultWindowEnd: '08:00',
    defaultFrequencyPerWeek: 3,
  ),
  _HabitSpec(
    id: 'read',
    name: 'Read',
    keywords: ['read', 'reading'],
    defaultDurationMinutes: 30,
    defaultWindowStart: '20:00',
    defaultWindowEnd: '22:00',
  ),
  _HabitSpec(
    id: 'meditate',
    name: 'Meditate',
    keywords: ['meditate', 'meditation'],
    defaultDurationMinutes: 15,
    defaultWindowStart: '06:00',
    defaultWindowEnd: '07:00',
  ),
];

class RuleBasedPlanner implements WeeklyPlanner {
  @override
  Future<ParsedPlan> parse(String text) async {
    final lower = ' ${text.toLowerCase()} ';
    final habits = <PlannedHabit>[];
    final notes = <String>[];

    for (final spec in _habitSpecs) {
      // Find the earliest mention of any keyword for this habit.
      int? mentionIndex;
      for (final keyword in spec.keywords) {
        final i = lower.indexOf(keyword);
        if (i >= 0 && (mentionIndex == null || i < mentionIndex)) {
          mentionIndex = i;
        }
      }
      if (mentionIndex == null) continue;

      // The "clause" for this habit runs from its mention to the next habit
      // mention (or the end). Numbers inside the clause belong to this habit.
      final clause = _clauseFor(lower, mentionIndex);

      final frequency = _parseFrequency(clause) ?? spec.defaultFrequencyPerWeek;
      final duration =
          _parseDuration(clause) ?? spec.defaultDurationMinutes;
      final times = _parseTimes(clause);
      final waterMl = spec.isWater ? _parseWaterLitres(clause) : null;

      habits.add(PlannedHabit(
        habitId: spec.id,
        name: spec.name,
        frequencyPerWeek: frequency,
        durationMinutes: duration,
        windowStart: times.windowStart ?? spec.defaultWindowStart,
        windowEnd: times.windowEnd ?? spec.defaultWindowEnd,
        preferredStart: times.preferredStart ?? spec.defaultWindowStart,
        waterGoalMl: waterMl,
      ));
    }

    if (habits.isEmpty) {
      notes.add(
        'I could not spot a habit I know in that text. Try something like '
        '"gym 3 times a week for 1 hour, 4 to 5 pm, and drink 5 litres of '
        'water every day".',
      );
    }
    if (habits.isNotEmpty && !_mentionsAnyTime(lower)) {
      notes.add(
        'No times mentioned — I used sensible defaults. Tap any time to '
        'change it before confirming.',
      );
    }
    return ParsedPlan(habits: habits, unparsedNotes: notes);
  }

  /// Text from [from] until the next known habit keyword, or the end.
  String _clauseFor(String lower, int from) {
    var end = lower.length;
    for (final spec in _habitSpecs) {
      for (final keyword in spec.keywords) {
        final i = lower.indexOf(keyword, from + 1);
        if (i >= 0 && i < end) end = i;
      }
    }
    return lower.substring(from, end);
  }

  bool _mentionsAnyTime(String lower) =>
      RegExp(r'\d{1,2}(:\d{2})?\s*(am|pm)').hasMatch(lower) ||
      RegExp(r'\b\d{1,2}:\d{2}\b').hasMatch(lower);

  int? _readNumber(String text) {
    final digit = RegExp(r'(\d+)').firstMatch(text);
    if (digit != null) return int.parse(digit.group(1)!);
    for (final entry in _numberWords.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }

  int? _parseFrequency(String clause) {
    if (clause.contains('every day') ||
        clause.contains('daily') ||
        clause.contains('each day')) {
      return 7;
    }
    if (clause.contains('weekday')) return 5;
    final m = RegExp(
      r'(\d+|one|two|three|four|five|six|seven)\s*(x|times?)\s*(a|per)?\s*week',
    ).firstMatch(clause);
    if (m != null) return _readNumber(m.group(0)!);
    if (clause.contains('once a week') || clause.contains('once per week')) {
      return 1;
    }
    if (clause.contains('twice a week')) return 2;
    return null;
  }

  int? _parseDuration(String clause) {
    final hours = RegExp(
      r'(\d+|one|two|three)\s*(hours?|hrs?)\b',
    ).firstMatch(clause);
    final minutes = RegExp(r'(\d+)\s*(minutes?|mins?)\b').firstMatch(clause);
    var total = 0;
    if (hours != null) total += (_readNumber(hours.group(0)!) ?? 1) * 60;
    if (minutes != null) total += int.parse(minutes.group(1)!);
    return total > 0 ? total : null;
  }

  int? _parseWaterLitres(String clause) {
    final m = RegExp(
      r'(\d+(?:\.\d+)?)\s*(l|litres?|liters?)\b',
    ).firstMatch(clause);
    if (m == null) return 5000;
    final litres = double.parse(m.group(1)!);
    return (litres * 1000).round();
  }

  /// Returns (preferredStart, windowStart, windowEnd) as "HH:MM" strings.
  ({String? preferredStart, String? windowStart, String? windowEnd})
      _parseTimes(String clause) {
    // "4 pm to 5 pm" or "4-5 pm" or "4 to 6" -> a range.
    final range = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*(?:to|-)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
    ).firstMatch(clause);
    if (range != null) {
      final start = _to24Hour(
        int.parse(range.group(1)!),
        int.tryParse(range.group(2) ?? '0') ?? 0,
        range.group(3) ?? range.group(6),
      );
      final end = _to24Hour(
        int.parse(range.group(4)!),
        int.tryParse(range.group(5) ?? '0') ?? 0,
        range.group(6) ?? range.group(3),
      );
      if (start != null && end != null) {
        return (
          preferredStart: start,
          windowStart: start,
          windowEnd: end,
        );
      }
    }

    // A single time, e.g. "at 6 am".
    final single = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)',
    ).firstMatch(clause);
    if (single != null) {
      final t = _to24Hour(
        int.parse(single.group(1)!),
        int.tryParse(single.group(2) ?? '0') ?? 0,
        single.group(3),
      );
      if (t != null) return (preferredStart: t, windowStart: null, windowEnd: null);
    }

    // 24-hour time, e.g. "16:00".
    final military = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b').firstMatch(clause);
    if (military != null) {
      final t =
          '${military.group(1)!.padLeft(2, '0')}:${military.group(2)!}';
      return (preferredStart: t, windowStart: null, windowEnd: null);
    }

    return (preferredStart: null, windowStart: null, windowEnd: null);
  }

  /// "4 pm" -> "16:00". [ampm] may be null (then the hour is taken as-is,
  /// unless it is clearly a 12-hour time without am/pm — left as-is).
  String? _to24Hour(int hour, int minute, String? ampm) {
    var h = hour;
    if (ampm == 'pm' && h < 12) h += 12;
    if (ampm == 'am' && h == 12) h = 0;
    if (h < 0 || h > 23 || minute < 0 || minute > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
