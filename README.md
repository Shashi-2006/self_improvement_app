# Self-Improvement App

> Turn a good habit into a hobby, like brushing teeth — at the set time the
> app gets you into the mood to start, so you don't skip it just because
> you're lazy. Use the phone to get AWAY from the phone.

A Flutter discipline / self-improvement app: habit timers, dynamic XP,
leaderboards, habit-only chat, an AI weekly planner, screen-time awareness
and a weekly orbit recap. Light and dark mode.

**Status: v1.0.0 — Full v1, local-first.** Everything works offline on the
phone. Leaderboard and chat use clearly-labelled demo data until Firebase is
connected (see [docs/firebase-setup.md](docs/firebase-setup.md)). Screen time
and focus lock use real Android APIs when Usage Access is granted; on web
they show clearly-labelled demo data.

**Security:** no secrets anywhere in the repo, salted password hashing,
login lockout after 5 wrong attempts (15 min), session tokens in secure
storage — see [SECURITY.md](SECURITY.md). **Demo:** the login screen has a
"Try the demo — no password needed" button that opens the full app with
sample data, read-only, enforced in code. **Web demo:** `flutter build web`
produces `build/web/` for Cloudflare Pages — see
[docs/cloudflare-pages.md](docs/cloudflare-pages.md).

## What it does

| Feature | Where | Notes |
|---|---|---|
| Login + lockout | Login screen | Local accounts, salted SHA-256 passwords, 5 wrong attempts → 15 min lockout, tokens in secure storage |
| Demo mode — "Try the demo, no password needed" | Login screen | Full app with sample data, read-only (enforced in state, not just hidden buttons), visible banner on every tab |
| Today habits — gym, study 1h, wake early, sleep on time, 5L water | Today tab | Time windows, "Are you doing it today?" |
| Timer — Pause / Resume / Finish | Today tab | Pausing never loses time; Finish banks XP on elapsed time only |
| Focus lock | Before starting the timer | "Unproductive apps on or off?" — Off blocks them while the timer runs (Android UsageStats, with permission flow + demo fallback) |
| Dynamic XP by task | Everywhere | Study 100 XP/h, Gym 80 XP/h, Wake 40/day, Sleep 40/day, Water 10 XP per 500 ml (max 50/day). Proportional: 30 min study = 50 XP. **0:00 = 0 XP.** Owner can edit rates in Settings |
| Water cap | Today → Water | Max 500 ml per log (10% of goal), max 1000 ml per hour (20%), "next log in X min" when the hourly cap is hit. Kidneys clear ~1 L/hour — 1250 ml in one go is over the limit |
| AI weekly planner | Plan tab | Describe the week in plain words → "Is this what you meant?" → edit timings inline → confirm. v1 parses on-device (rule-based, offline); a real LLM plugs in at one point — see `lib/services/plan_parser.dart` |
| End-of-day recap | Progress tab | What was done, what was missed, comparison with yesterday |
| Weekly utilised-vs-wasted chart | Progress tab | Planned vs done + excess screen time |
| Screen time | Progress tab | Top 5 apps by minutes; productive / non-productive / **You decide**. LinkedIn, WhatsApp, YouTube are never hard-coded — the user tags them. Spike prompt when unclassified usage rises |
| Weekly orbit recap | Progress tab | Top wasting apps fly in one by one, orbit fast, top app pops up, then deltas vs last week, then the reality check (2h wasted/day → ~60h/month → 60 gym sessions) |
| Leaderboard | Ranks tab | Friends + global (demo data in v1) |
| Habit-only chat | Ranks tab → Gym Crew | Ask how others do the habit. Not general chat, not dating |
| Light / dark mode | Header toggle + Settings | Choice is remembered |

## Run it

```bash
# 1. Install Flutter (stable channel) — https://docs.flutter.dev/get-started/install
flutter --version

# 2. Get dependencies
flutter pub get

# 3. Check, test, run
flutter analyze
flutter test
flutter run            # on a connected Android phone / emulator
flutter build apk --debug
flutter build web      # demo build (screen time + focus lock show demo data)
```

> **Launcher icons:** the stock Flutter template icon PNGs
> (`android/.../mipmap-*/ic_launcher.png`, iOS `AppIcon` set,
> `web/icons/*`, `web/favicon.png`) are **not in this repo** — the GitHub
> upload used here cannot push binary files. Android/iOS builds need
> them; regenerate with `flutter_launcher_icons` or copy them from a
> fresh `flutter create` template. The web build works without them.

**Android permissions (real phone only):** screen time and focus lock need
Usage Access — the app opens the Android settings screen for it. Without the
permission the app falls back to demo data and says so.

## Architecture — how the code is organised

```
lib/
  main.dart            Front door: creates AppState, picks the theme, 5 tabs
  models/              Plain data: Habit, HabitSession, WaterLog, WeeklyPlan,
                       AppUsageEntry, ChatMessage, LeaderboardEntry
  services/            The rules (no UI in here):
    xp_calculator.dart    Proportional XP, owner rates, level maths
    water_cap.dart        500 ml/log + 1000 ml/hour caps + cooldown
    plan_parser.dart      Plain-words → structured plan (rule-based v1,
                          WeeklyPlanner interface for a real LLM later)
    screen_time_service.dart   Android UsageStats via MethodChannel + demo fallback
    focus_lock_service.dart    Foreground-app watch + bring-to-front
    local_store.dart      Save/load all state as JSON on the phone
    firebase_backend.dart Backend interface + local impl + Firestore design
    recap_service.dart    End-of-day recap, weekly totals, reality check
  state/
    app_state.dart     The ONE object that owns all data (ChangeNotifier).
                       Timer state machine, water, plan, usage, chat.
  screens/             Today, Plan, Progress, Ranks, Settings
  widgets/             Shared cards, weekly chart (CustomPainter),
                       orbit recap animation
  theme/               Light + dark themes (emerald / amber / sky)
test/
  xp_calculator_test.dart   · water_cap_test.dart   · plan_parser_test.dart
  widget_smoke_test.dart    (app launches, all 5 tabs render)
```

### Concepts, in plain words (for interviews)

- **Dart** is the language — typed, object-oriented, like Java. A `class`
  is a blueprint; an `object` is one thing made from it.
- **Flutter** builds the UI from **Widgets** — a button is a widget, a whole
  screen is a widget made of smaller widgets, like components in React.
- **ChangeNotifier** is the state pattern used here: `AppState` holds the
  data and calls `notifyListeners()` when it changes; screens rebuild.
- **MethodChannel** is the bridge to native Android code: Dart asks
  ("which app is in the foreground?"), Kotlin answers.
- **Firebase** (later) is the backend without a server: Auth = login,
  Firestore = database for habits / XP / chats. XP is always recomputed
  server-side — the client is never trusted with its own score.
- **Local-first** means the app works with no internet and no account, and
  the same code later syncs to Firebase through one interface.

## Firebase — turning the backend on

There is **no Firebase project and no credential in this repo**. To enable
it: create the project in the Firebase console, add
`google-services.json`, add the Firebase packages, implement
`FirestoreBackend`, and flip one flag. Full steps + security rules +
collection design: [docs/firebase-setup.md](docs/firebase-setup.md).

## Roadmap

- [ ] Firebase project + Auth (anonymous, then Google) + Firestore sync
- [ ] Server-side XP via Cloud Function (leaderboard becomes real)
- [ ] Real focus-lock verification on a physical Android phone
- [ ] Notifications for habit windows + end-of-day recap
- [ ] iOS build (screen time via FamilyControls — much more restricted)
- [ ] Play Store release build (signing + privacy policy)

## License

Personal project by Shashwat Sharma. Free to learn from; please don't
re-publish it as your own.
