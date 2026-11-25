// ─────────────────────────────────────────────────────────────────────────────
// SELF-IMPROVEMENT APP — v1.0.0 (Full v1)
//
// The idea: turn a good habit into a hobby, like brushing teeth — at the set
// time the app gets you into the mood to start, so you don't skip it just
// because you're lazy. Use the phone to get AWAY from the phone.
//
// WHAT THIS FILE DOES: it is the front door. It creates the AppState, loads
// the saved data, restores the session, and shows one of two things:
//   * the login screen (with the "Try the demo" button), or
//   * the 5 tabs: Today · Plan · Progress · Ranks · Settings.
// In Demo Mode an amber banner stays visible at the top of every tab.
//
// HOW TO READ THIS PROJECT (for Shashwat — Dart beginner notes):
//  * lib/models/      — plain data classes (Habit, WaterLog, ...)
//  * lib/services/    — the rules: XP maths, water cap, plan parsing,
//                       screen time, focus lock, Firebase interface,
//                       auth (local accounts + lockout + secure storage)
//  * lib/state/       — AppState: the one object that owns all data
//  * lib/screens/     — login + the 5 tabs
//  * lib/widgets/     — shared cards, the weekly chart, the orbit recap
//  * lib/theme/       — light + dark themes
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/ranks_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/today_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SelfImprovementApp());
}

class SelfImprovementApp extends StatefulWidget {
  /// Optional state injection — the real app always omits it and gets a
  /// default AppState. Widget tests pass one built with in-memory auth
  /// stores, because the real secure-storage channel has no test mock and
  /// its read would never return, leaving the app on the loading spinner.
  const SelfImprovementApp({super.key, AppState? state})
      : _injectedState = state;

  final AppState? _injectedState;

  @override
  State<SelfImprovementApp> createState() => _SelfImprovementAppState();
}

class _SelfImprovementAppState extends State<SelfImprovementApp> {
  late final AppState _state = widget._injectedState ?? AppState();
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load saved data + restore the session, then rebuild. Until then the
    // loading spinner shows.
    _state.load();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder rebuilds this widget whenever AppState calls
    // notifyListeners() — that is how the timer ticks and the theme flips.
    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) {
        if (!_state.loaded) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading your habits…',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final signedIn = _state.isSignedIn || _state.demoMode;
        return MaterialApp(
          title: 'Self-Improvement App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          // The toggle in the header flips this; the choice is saved.
          themeMode: _state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: signedIn
              ? _TabsScaffold(
                  state: _state,
                  tabIndex: _tabIndex,
                  onTabChanged: (index) => setState(() => _tabIndex = index),
                )
              : LoginScreen(state: _state),
        );
      },
    );
  }
}

/// The 5-tab scaffold, with the Demo Mode banner on top when applicable.
class _TabsScaffold extends StatelessWidget {
  const _TabsScaffold({
    required this.state,
    required this.tabIndex,
    required this.onTabChanged,
  });

  final AppState state;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Self-Improvement'),
        actions: [
          IconButton(
            tooltip: state.isDarkMode
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            icon: Icon(
              state.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: state.toggleTheme,
          ),
          IconButton(
            tooltip: state.demoMode ? 'Exit demo' : 'Sign out',
            icon: Icon(state.demoMode ? Icons.exit_to_app : Icons.logout),
            onPressed: () async {
              if (state.demoMode) {
                state.exitDemo();
              } else {
                await state.signOut();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Demo Mode banner: always visible, on every tab ─────────────
          if (state.demoMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              color: AppTheme.amber,
              child: Row(
                children: [
                  const Icon(Icons.visibility, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'DEMO MODE — sample data, read-only. '
                      'Nothing you do here is saved.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: state.exitDemo,
                    child: const Text(
                      'Exit demo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              // IndexedStack keeps all 5 tabs alive, so the timer keeps
              // ticking when you look at Progress and come back.
              index: tabIndex,
              children: [
                TodayScreen(state: state),
                PlannerScreen(state: state),
                ProgressScreen(state: state),
                RanksScreen(state: state),
                SettingsScreen(state: state),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
        onTap: onTabChanged,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'Plan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Ranks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
