# Firebase setup — enable the real backend

v1 runs **fully offline** on the phone (local storage). Nothing in this repo
talks to Firebase yet, and there are **no credentials here** — no
`google-services.json`, no API key, nothing to leak. Follow these steps when
you are ready to turn the backend on.

## 1. Create the project

1. Go to [Firebase console](https://console.firebase.google.com) → Add project
   → name it `self-improvement-app`.
2. Add an Android app: package name `com.shashwat.self_improvement_app`
   (see `android/app/build.gradle.kts` — the applicationId must match).
3. Download `google-services.json` and put it in `android/app/`.
   **Never commit a file from someone else's console, and never paste keys
   into code or chat.**
4. Add an iOS app later the same way (`GoogleService-Info.plist` in
   `ios/Runner/`).

## 2. Enable the products

- **Authentication** → Sign-in method → enable **Anonymous** first
  (no login screen needed for v1), then **Google** when you want accounts.
- **Firestore Database** → Create database → production mode.
- **Cloud Functions** (optional, for the leaderboard) — see step 4.

## 3. Add the packages and flip the switch

```yaml
# pubspec.yaml — add under dependencies:
firebase_core: ^3.0.0
firebase_auth: ^5.0.0
cloud_firestore: ^5.0.0
```

Then implement `FirestoreBackend` in
`lib/services/firebase_backend.dart` (each method currently throws
`UnimplementedError` with this pointer) using the collection design in the
header comment of that file, and flip the backend in
`lib/state/app_state.dart` (`_backend = FirestoreBackend()`).

## 4. Firestore security rules — the part that makes it secure

Paste these into Firestore → Rules. They are the whole point: **the client
is never trusted with its own XP.**

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // A user can read/write ONLY their own data.
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }

    // Leaderboard: clients may READ, never write. A Cloud Function with the
    // Admin SDK recomputes it from users' sessions.
    match /leaderboard/{scope} {
      allow read: if request.auth != null;
      allow write: if false;
    }

    // Chat: only members of the group may read; anyone in the group may
    // CREATE a message, but nobody may edit or delete one.
    match /groups/{groupId}/messages/{messageId} {
      allow read: if request.auth != null
        && request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.memberUids;
      allow create: if request.auth != null
        && request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.memberUids
        && request.resource.data.authorUid == request.auth.uid;
      allow update, delete: if false;
    }
    match /groups/{groupId} {
      allow read: if request.auth != null
        && request.auth.uid in resource.data.memberUids;
    }
  }
}
```

## 5. Server-side XP (do this before launch)

Never accept "give me 1000 XP" from a client. The Cloud Function flow:

1. Client writes a `sessions` document: habit, elapsed seconds, date.
2. A Firestore trigger recomputes XP with the **same formula as
   `lib/services/xp_calculator.dart`** (proportional, 0:00 = 0 XP) and
   updates `users/{uid}.totalXp` and the leaderboard.
3. The client only ever *displays* the total the server computed.

Until this exists, the leaderboard and chat stay on local demo data and are
labelled as such in the UI.

## 6. Collection design (summary)

```
users/{uid}                     displayName, totalXp, level, streakDays
  habits/{habitId}              name, kind, targetMinutes, window, frequency
  sessions/{sessionId}          habitId, date, elapsedSeconds, xpEarned, mood
  waterLogs/{logId}             at, ml
  plans/{planId}                text, habits[], createdAt
groups/{groupId}                name, habitId, memberUids[]
  messages/{messageId}          authorUid, authorName, text, at
leaderboard/{friends|global}    entries[]  (Cloud Function only)
```
