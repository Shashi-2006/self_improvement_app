# Security — Self-Improvement App

Same bar as the Inventory Management System: no secrets in the repo, login
lockout, secure token storage, and Firestore rules that make the server the
authority. This file documents what v1 actually does, what it does not do
yet, and what to verify before launch.

## 1. No secrets in the repo — ever

- There is **no Firebase config** (`google-services.json`,
  `GoogleService-Info.plist`), **no API key**, **no token**, **no password**
  anywhere in this repository. v1 runs fully offline and needs none of them.
- When Firebase is enabled, the config files come from **your own Firebase
  console** (see `docs/firebase-setup.md`). They are listed in
  `.gitignore` — check with `git status` before every commit.
- Never paste a key into code, chat, or a screenshot. If a secret is ever
  committed by mistake: revoke it in the provider console immediately,
  then rewrite the history — deleting the file in a later commit is not
  enough, the secret stays in the history.

## 2. Login + lockout (local accounts, v1)

Implemented in `lib/services/auth_service.dart`:

- **Passwords are never stored in plain text.** They are salted and hashed
  with SHA-256, iterated 1,000 times. Only the salt and the hash are kept.
  (A server would use bcrypt/argon2 — this is the honest local equivalent.
  When Firebase Auth is enabled, this whole file is replaced by it.)
- **Minimum password length: 10 characters** (same as the Inventory
  Management System).
- **Lockout: 5 wrong attempts → locked for 15 minutes.** The lockout is
  enforced in `AuthService`, not in the UI — the login screen cannot
  bypass it, and it survives an app restart. The error message never says
  whether the email exists, so nobody can probe for accounts.
- **Sessions are JWTs** (`lib/services/jwt_service.dart`, HS256). On
  sign-in the app issues a signed token (subject = the email, 7-day
  expiry) and stores it in `flutter_secure_storage` — Android Keystore /
  iOS Keychain. Signing out deletes the token. On startup the token's
  signature and expiry are VERIFIED before it is trusted; a tampered or
  expired token signs the user out. The signing key is generated once per
  device and kept in secure storage — never in code, so a token cannot be
  forged from the source alone. Honest limit: a stolen JWT is usable
  until it expires (7 days), and the key lives on the device, so this
  proves "issued here, not tampered with" — not identity to a server.
  Real server-side verification arrives with Firebase Auth ID tokens.
- **Web caveat (be honest about it):** `flutter_secure_storage` on web
  stores in browser localStorage, which is not hardware-backed. Real
  accounts on the web build are therefore session-scoped, and the portfolio
  demo uses **Demo Mode**, not a real account.

## 3. Secure storage — what lives where

| Data | Where | Why it is safe |
|---|---|---|
| Session token (JWT), lockout state, JWT signing key | `flutter_secure_storage` (Keystore / Keychain) | Hardware-backed on mobile, never plain text |
| Password hash + salt | SharedPreferences (local accounts) | A hash is not a password; 1,000-round SHA-256 makes guessing slow |
| Habits, sessions, water, XP | SharedPreferences (JSON) | Local-only data; no account, no network in v1 |
| Firebase config (later) | `google-services.json` from your console | `.gitignore`d; never committed |

Nothing is stored in plain `localStorage` / plain text on mobile. The demo
never touches any of the above — see §5.

## 4. Firestore rules — the server is the authority

`firestore.rules` (paste into the Firebase console; the file alone does not
activate them):

- **A user can read/write ONLY their own data** (`users/{their-uid}/**`).
  Any other uid is denied.
- **Leaderboard is read-only for clients.** Only a Cloud Function with the
  Admin SDK writes it.
- **XP is never accepted from a client.** Clients write *sessions* (habit,
  elapsed seconds, date). A Cloud Function recomputes XP with the same
  formula as `lib/services/xp_calculator.dart` (proportional, 0:00 = 0 XP)
  and updates the totals. A client saying "give me 1000 XP" is rejected by
  design.
- **Chat is append-only**: group members may create a message as
  themselves; nobody may edit or delete any message.
- **No catch-all rule**: any collection not listed is denied by default.

Verify after pasting: in the Firebase console, use the Rules Playground to
confirm (a) user A cannot read user B's document, (b) a client write to
`leaderboard/global` is denied.

## 5. Demo Mode — read-only, enforced in code

The portfolio demo ("Try the demo — no password needed") opens the full app
with sample data and **no account**:

- **Enforced in the state layer, not the UI.** `AppState.demoMode` is
  checked at the top of every method that would change data
  (`finishTimer`, `checkIn`, `tryLogWater`, `confirmPlan`,
  `sendChatMessage`, `setUsageTag`, `setAppLimit`, `updateXpRates`,
  `resetAllData`). Each refuses and records why. Hiding a button would not
  be enough — the methods themselves refuse, so no screen can write by
  accident. `_save()` also returns early in demo mode, so nothing reaches
  disk at all.
- **The timer is the one exception, on purpose**: a demo visitor may run
  the timer as a transient preview. Finishing it in demo discards the
  session and banks 0 XP, and says so.
- **A visible banner** ("DEMO MODE — sample data, read-only") stays at the
  top of every tab, with an Exit button.
- **No real user data is ever shown in demo.** The demo data is seeded
  sample data (a sample week, demo friends, demo chat) — it is not anyone's
  account, and demo mode cannot reach the local account's data at all.

## 6. What v1 does NOT do yet (be honest before launch)

- **No server-side XP yet.** Leaderboard and chat are local demo data in
  v1, labelled as such. They become real only with Firebase + the Cloud
  Function in `docs/firebase-setup.md` §5.
- **Local accounts share one device data store.** In v1, two accounts on
  the same phone share the same local habits/sessions (the password and
  lockout still protect the session). Per-user data separation is a
  Firebase feature — it arrives with Firestore, where rules enforce it.
- **No certificate pinning / no encryption-at-rest beyond the OS.**
  SharedPreferences data is protected by the OS sandbox, not encrypted by
  the app. If the app ever stores sensitive health data, add encrypted
  storage (e.g. `flutter_secure_storage` for tokens already; consider
  SQLCipher for the database) before launch.
- **Focus lock and screen time are Android-only** and need Usage Access
  permission. They degrade gracefully to labelled demo data without it.

## 7. Reporting a security issue

This is a personal project. If you find a vulnerability, do not open a
public issue — email the owner (Shashwat Sharma) directly with the details
and a reproduction, and allow time to fix it before disclosing anything.
