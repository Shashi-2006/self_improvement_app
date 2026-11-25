// ─────────────────────────────────────────────────────────────────────────────
// FIREBASE BACKEND — the interface, a local implementation, and the plan.
//
// STATUS IN V1: there is NO Firebase project yet and NO credentials in this
// repo — on purpose. Inventing a google-services.json or an API key would be
// fake and insecure. So v1 runs fully offline on [LocalBackend] (the same
// data the screens already use). When Shashwat creates a real Firebase
// project, the app switches to [FirestoreBackend] by adding the real config
// files and flipping one flag in lib/state/app_state.dart. The screens do
// not change at all, because they only talk to the [Backend] interface.
//
// FIRESTORE DESIGN (what to create — also in docs/firebase-setup.md):
//   users/{uid}
//     displayName, totalXp, level, streakDays, createdAt
//     xpRates: { studyPerHour, gymPerHour, wakePerDay, sleepPerDay,
//                waterPer500ml, waterMaxPerDay }   <- owner-editable rates
//     habits/{habitId}
//       name, kind, targetMinutes, windowStart, windowEnd, frequencyPerWeek
//     sessions/{sessionId}
//       habitId, date, elapsedSeconds, xpEarned, mood, completed
//     waterLogs/{logId}
//       at (timestamp), ml
//     plans/{planId}
//       text, habits: [...], createdAt
//   groups/{groupId}            <- e.g. "gym-crew"
//     name, habitId, memberUids: [...]
//     messages/{messageId}
//       authorUid, authorName, text, at
//   leaderboard/{scope}         <- "friends" and "global" docs
//     entries: [{ name, xp }]   <- recomputed by a Cloud Function from
//                                  users' totalXp; never trust the client
//                                  to write its own rank.
//
// SECURITY RULES (the part that makes it "secure" later):
//   * A user can read/write ONLY their own users/{uid} subtree.
//   * Leaderboard entries are read-only for clients; only a Cloud Function
//     (with the Admin SDK) writes them, so nobody can fake their XP.
//   * Chat messages can be created but never edited or deleted by clients,
//     and only by members of that group.
//   * XP is ALWAYS recomputed server-side from sessions. The client sends
//     "I did 30 minutes of study"; the server decides that is 50 XP.
//     Never accept "give me 1000 XP" from a client.
// ─────────────────────────────────────────────────────────────────────────────

import '../models/app_models.dart';

/// Everything the app needs from a backend, whether local or Firebase.
/// The screens only ever see this interface.
abstract class Backend {
  /// A stable id for this device/user. Local: a random id saved on the
  /// phone. Firebase: the Auth uid (anonymous sign-in in v1, Google later).
  Future<String> userId();

  Future<void> saveSession(HabitSession session);
  Future<void> saveWaterLog(WaterLog log);
  Future<void> savePlan(WeeklyPlan plan);

  /// Friends + global leaderboard. Local: seeded demo friends.
  /// Firebase: read from leaderboard/{scope}.
  Future<List<LeaderboardEntry>> leaderboard({required bool friendsOnly});

  /// Messages of one habit-only group. Local: seeded demo messages.
  /// Firebase: groups/{groupId}/messages ordered by `at`.
  Future<List<ChatMessage>> messages(String groupId);

  /// Send one message to a habit-only group.
  Future<void> sendMessage(String groupId, ChatMessage message);
}

/// The v1 backend: everything on the phone, no network, no account.
/// It also seeds the demo leaderboard and the Gym Crew chat so the Ranks tab
/// has something real to show on first launch.
class LocalBackend implements Backend {
  LocalBackend({required this.seedMessages, required this.seedLeaderboard});

  /// Mutable in-memory copies, seeded by AppState on startup.
  final List<ChatMessage> seedMessages;
  final List<LeaderboardEntry> seedLeaderboard;

  @override
  Future<String> userId() async => 'local-user';

  @override
  Future<void> saveSession(HabitSession session) async {
    // Local persistence is handled by LocalStore saving the whole AppState.
    // This method exists so the Firebase version can hook in here later.
  }

  @override
  Future<void> saveWaterLog(WaterLog log) async {}

  @override
  Future<void> savePlan(WeeklyPlan plan) async {}

  @override
  Future<List<LeaderboardEntry>> leaderboard({required bool friendsOnly}) async {
    // v1: the same seeded friends for both scopes; the global list is
    // clearly labelled "Demo" until Firebase provides real rankings.
    return List<LeaderboardEntry>.unmodifiable(seedLeaderboard);
  }

  @override
  Future<List<ChatMessage>> messages(String groupId) async =>
      List<ChatMessage>.unmodifiable(seedMessages);

  @override
  Future<void> sendMessage(String groupId, ChatMessage message) async {
    seedMessages.add(message);
  }
}

/// The Firebase implementation — a deliberate stub in v1.
///
/// To enable it (after creating the Firebase project, see
/// docs/firebase-setup.md):
///   1. Add firebase_core, firebase_auth, cloud_firestore to pubspec.yaml.
///   2. Add google-services.json (Android) / GoogleService-Info.plist (iOS)
///      from the Firebase console. NEVER commit a file you did not get from
///      your own console, and never paste keys into code or chat.
///   3. Implement each method below against Firestore using the collection
///      design at the top of this file, then flip the flag in AppState.
/// Until then every method throws, so a half-wired build fails loudly
/// instead of silently pretending to sync.
class FirestoreBackend implements Backend {
  @override
  Future<String> userId() => throw UnimplementedError(
        'Firebase is not configured yet. See docs/firebase-setup.md.',
      );

  @override
  Future<void> saveSession(HabitSession session) => throw UnimplementedError(
        'Firebase is not configured yet. See docs/firebase-setup.md.',
      );

  @override
  Future<void> saveWaterLog(WaterLog log) => throw UnimplementedError(
        'Firebase is not configured yet. See docs/firebase-setup.md.',
      );

  @override
  Future<void> savePlan(WeeklyPlan plan) => throw UnimplementedError(
        'Firebase is not configured yet. See docs/firebase-setup.md.',
      );

  @override
  Future<List<LeaderboardEntry>> leaderboard({required bool friendsOnly}) =>
      throw UnimplementedError(
        'Firebase is not configured yet. See docs/firebase-setup.md.',
      );

  @override
  Future<List<ChatMessage>> messages(String groupId) =>
      throw UnimplementedError(
        'Firebase is not configured yet. See docs/firebase-setup.md.',
      );

  @override
  Future<void> sendMessage(String groupId, ChatMessage message) =>
      throw UnimplementedError(
        'Firebase is not configured yet. See docs/firebase-setup.md.',
      );
}
