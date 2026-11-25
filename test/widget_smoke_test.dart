// Smoke tests: the app launches on the login screen, the demo button opens
// the full app with the banner, and all 5 tabs render. This catches crashes
// on startup — the most common first-build failure — without testing every
// pixel.
//
// NOTE: widget tests run with mock SharedPreferences, so AppState.load()
// finishes with no saved data and no session — the login screen shows.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_improvement_app/main.dart';
import 'package:self_improvement_app/services/auth_service.dart';
import 'package:self_improvement_app/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The app with in-memory auth stores: the real secure-storage channel has
// no test mock, so its session-restore read never returns and the app stays
// on the loading spinner forever (pumpAndSettle times out).
Widget _testApp() => SelfImprovementApp(
      state: AppState(
        auth: AuthService(
          tokens: MemoryTokenStore(),
          accounts: MemoryAccountStore(),
        ),
      ),
    );

Future<void> _enterDemo(WidgetTester tester) async {
  await tester.pumpWidget(_testApp());
  await tester.pumpAndSettle();
  expect(find.text('Try the demo — no password needed'), findsOneWidget);
  await tester.tap(find.text('Try the demo — no password needed'));
  await tester.pumpAndSettle();
  expect(find.textContaining('DEMO MODE'), findsOneWidget);
}

void main() {
  setUpAll(() {
    // SharedPreferences needs mock values in widget tests, or
    // getInstance() throws and the app never leaves the loading screen.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app launches on the login screen', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('Self-Improvement'), findsOneWidget);
    expect(find.text('Try the demo — no password needed'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('demo opens Today with the 5 habits and all 5 tabs',
      (tester) async {
    await _enterDemo(tester);

    // The habit list is scrollable and the test viewport is short, so
    // cards below the fold are not built until scrolled to.
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Study'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Wake up early'), 200);
    expect(find.text('Wake up early'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sleep on time'), 200);
    expect(find.text('Sleep on time'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Drink water'), 200);
    expect(find.text('Drink water'), findsOneWidget);

    // All 5 tabs exist.
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Ranks'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('tapping Plan opens the planner', (tester) async {
    await _enterDemo(tester);

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Make my plan'), findsOneWidget);
  });

  testWidgets('tapping Progress opens the chart and orbit recap',
      (tester) async {
    await _enterDemo(tester);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    // The recap sections sit below the chart in a scrollable column.
    // SectionTitle renders its text uppercased.
    await tester.scrollUntilVisible(find.text('END-OF-DAY RECAP'), 200);
    expect(find.text('END-OF-DAY RECAP'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('WEEKLY ORBIT RECAP'), 200);
    expect(find.text('WEEKLY ORBIT RECAP'), findsOneWidget);
  });

  testWidgets('demo mode is read-only: finishing a timer does not save',
      (tester) async {
    await _enterDemo(tester);

    // Start the Gym timer, then finish it. A running timer ticks every
    // second, so pumpAndSettle would never settle — pump manually instead.
    await tester.tap(find.text('Start timer').first);
    await tester.pump();
    // Focus-lock dialog: choose "On — allow them".
    await tester.tap(find.text('On — allow them'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Finish'));
    await tester.pump();
    expect(find.textContaining('Demo mode'), findsWidgets);
  });
}
