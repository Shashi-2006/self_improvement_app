// ─────────────────────────────────────────────────────────────────────────────
// AUTH — local accounts, lockout, and JWT sessions.
//
// THE HONEST VERSION: v1 has NO server. Accounts live on the phone, and the
// code below is the real thing for a local-first app — not a mock:
//  * Passwords are NEVER stored in plain text. They are salted and hashed
//    with SHA-256 (1,000 rounds) and only the hash is kept.
//  * Sessions are JWTs (see lib/services/jwt_service.dart): on sign-in the
//    app issues a signed token (subject = email, 7-day expiry) and stores
//    it in flutter_secure_storage: Android Keystore / iOS Keychain. On web
//    it falls back to browser storage (see SECURITY.md) — which is why the
//    portfolio demo uses Demo Mode, not a real account.
//  * On startup, restoreSession() VERIFIES the token's signature and expiry
//    before trusting it. A tampered or expired token signs the user out.
//    The signing key is generated once per device and kept in secure
//    storage — it never lives in code, so a token cannot be forged from
//    the source alone.
//  * After 5 wrong passwords the account locks for 15 minutes.
//    (Same bar as the Inventory Management System: 5 attempts / 15 min.)
//
// WHEN FIREBASE IS ENABLED, this whole file is replaced by Firebase Auth
// (anonymous, then Google) — whose ID tokens are JWTs too, verified
// server-side by the Admin SDK. The lockout rule moves server-side — a
// local lockout cannot protect a server account. The rest of the app does
// not change: it only asks "who is signed in?" and "are we in demo mode?"
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jwt_service.dart';

/// After this many wrong passwords, the account locks.
const int maxFailedAttempts = 5;

/// How long a lockout lasts.
const Duration lockoutDuration = Duration(minutes: 15);

/// Minimum password length (same bar as the Inventory Management System).
const int minPasswordLength = 10;

/// How long a signed-in session lasts. After this the JWT expires and
/// restoreSession() signs the user out — they sign in again. Short enough
/// that a stolen token stops working on its own; long enough that the app
/// does not nag every day.
const Duration sessionDuration = Duration(days: 7);

/// Where a session token is kept. The interface exists so tests can use an
/// in-memory store instead of the phone's Keystore/Keychain.
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Real token storage: Android Keystore / iOS Keychain via
/// flutter_secure_storage. Never plain text, never SharedPreferences.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// In-memory token store — for tests only.
class MemoryTokenStore implements TokenStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async {
    _map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _map.remove(key);
  }
}

/// Where local accounts are kept (hashes only — never passwords).
/// Same interface trick as TokenStore: SharedPreferences in the app,
/// in-memory in tests.
abstract class AccountStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SharedPrefsAccountStore implements AccountStore {
  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

/// In-memory account store — for tests only.
class MemoryAccountStore implements AccountStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async {
    _map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _map.remove(key);
  }
}

/// The outcome of a sign-up / sign-in attempt.
class AuthResult {
  const AuthResult({required this.ok, this.error, this.lockedUntil});

  final bool ok;

  /// Human-readable reason when [ok] is false.
  final String? error;

  /// When set, the account is locked until this time.
  final DateTime? lockedUntil;
}

/// One local account: email + salted hash. The password itself is never
/// stored anywhere.
class _Account {
  _Account({required this.email, required this.salt, required this.hash});

  final String email;
  final String salt;
  final String hash;

  Map<String, dynamic> toJson() =>
      {'email': email, 'salt': salt, 'hash': hash};

  factory _Account.fromJson(Map<String, dynamic> json) => _Account(
        email: json['email'] as String,
        salt: json['salt'] as String,
        hash: json['hash'] as String,
      );
}

class AuthService {
  AuthService({
    TokenStore? tokens,
    AccountStore? accounts,
    DateTime Function()? now,
  })  : _tokens = tokens ?? SecureTokenStore(),
        _accounts = accounts ?? SharedPrefsAccountStore(),
        _now = now ?? DateTime.now;

  final TokenStore _tokens;
  final AccountStore _accounts;
  final DateTime Function() _now;

  static const _sessionKey = 'sia_session_token';
  static const _sessionEmailKey = 'sia_session_email';

  /// The per-device JWT signing key (base64url of 32 random bytes).
  /// Generated once and kept in secure storage — never in code, never in
  /// SharedPreferences. Deleting it invalidates every session on the
  /// device, because no new token can be verified against the old key.
  static const _jwtKey = 'sia_jwt_signing_key';

  String _accountKey(String email) =>
      'sia_account_${email.trim().toLowerCase()}';
  String _lockoutKey(String email) =>
      'sia_lockout_${email.trim().toLowerCase()}';

  /// Creates a local account and signs in. Returns an error (not a crash)
  /// for a bad email, a short password, or an email that already exists.
  Future<AuthResult> signUp(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_looksLikeEmail(cleanEmail)) {
      return const AuthResult(
        ok: false,
        error: 'That does not look like an email address.',
      );
    }
    if (password.length < minPasswordLength) {
      return const AuthResult(
        ok: false,
        error: 'Password must be at least $minPasswordLength characters.',
      );
    }
    if (await _accounts.read(_accountKey(cleanEmail)) != null) {
      return const AuthResult(
        ok: false,
        error: 'An account with that email already exists — try signing in.',
      );
    }
    final salt = _randomSalt();
    final account = _Account(
      email: cleanEmail,
      salt: salt,
      hash: _hashPassword(password, salt),
    );
    await _accounts.write(
      _accountKey(cleanEmail),
      jsonEncode(account.toJson()),
    );
    await _createSession(cleanEmail);
    return const AuthResult(ok: true);
  }

  /// Signs in. Wrong passwords count towards the lockout; the error never
  /// says whether the email exists (that would let someone probe accounts).
  Future<AuthResult> signIn(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final lockedUntil = await _lockedUntil(cleanEmail);
    if (lockedUntil != null && lockedUntil.isAfter(_now())) {
      final minutes = lockedUntil.difference(_now()).inMinutes + 1;
      return AuthResult(
        ok: false,
        error: 'Too many wrong attempts — try again in $minutes min.',
        lockedUntil: lockedUntil,
      );
    }

    final raw = await _accounts.read(_accountKey(cleanEmail));
    var passwordMatches = false;
    if (raw != null) {
      final account =
          _Account.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      passwordMatches =
          _hashPassword(password, account.salt) == account.hash;
    }

    if (!passwordMatches) {
      await _recordFailedAttempt(cleanEmail);
      final locked = await _lockedUntil(cleanEmail);
      if (locked != null && locked.isAfter(_now())) {
        return AuthResult(
          ok: false,
          error: 'Too many wrong attempts — locked for 15 minutes.',
          lockedUntil: locked,
        );
      }
      return const AuthResult(
        ok: false,
        error: 'Wrong email or password.',
      );
    }

    await _clearFailedAttempts(cleanEmail);
    await _createSession(cleanEmail);
    return const AuthResult(ok: true);
  }

  /// Signs out: the token is deleted from secure storage.
  Future<void> signOut() async {
    await _tokens.delete(_sessionKey);
    await _tokens.delete(_sessionEmailKey);
  }

  /// On startup: is there a valid saved session? Returns the email, or
  /// null when nobody is signed in (or the token was tampered with or
  /// expired). The JWT itself carries the subject and the expiry — the
  /// signature is what proves it is genuine, so no account lookup is
  /// needed to trust it.
  Future<String?> restoreSession() async {
    final token = await _tokens.read(_sessionKey);
    final email = await _tokens.read(_sessionEmailKey);
    if (token == null || email == null) return null;
    final jwt = await _jwt();
    final claims = jwt.verify(token, now: _now());
    if (claims == null || claims['sub'] != email) {
      // Tampered, expired, or for a different email — do not trust it.
      await signOut();
      return null;
    }
    return email;
  }

  // ── Lockout bookkeeping ──────────────────────────────────────────────────

  Future<DateTime?> _lockedUntil(String email) async {
    final raw = await _tokens.read(_lockoutKey(email));
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final until = data['until'] as String?;
    if (until == null) return null;
    final parsed = DateTime.parse(until);
    if (parsed.isBefore(_now())) {
      await _tokens.delete(_lockoutKey(email));
      return null;
    }
    return parsed;
  }

  Future<void> _recordFailedAttempt(String email) async {
    final key = _lockoutKey(email);
    final raw = await _tokens.read(key);
    var attempts = 0;
    if (raw != null) {
      attempts = (jsonDecode(raw) as Map<String, dynamic>)['attempts'] as int? ?? 0;
    }
    attempts += 1;
    if (attempts >= maxFailedAttempts) {
      await _tokens.write(
        key,
        jsonEncode({
          'attempts': 0,
          'until': _now().add(lockoutDuration).toIso8601String(),
        }),
      );
    } else {
      await _tokens.write(key, jsonEncode({'attempts': attempts}));
    }
  }

  Future<void> _clearFailedAttempts(String email) async {
    await _tokens.delete(_lockoutKey(email));
  }

  // ── JWT sessions ─────────────────────────────────────────────────────────

  /// Loads the per-device signing key (generating it on first use) and
  /// returns a JwtService bound to it.
  Future<JwtService> _jwt() async {
    var encoded = await _tokens.read(_jwtKey);
    if (encoded == null) {
      encoded = _randomToken();
      await _tokens.write(_jwtKey, encoded);
    }
    return JwtService(signingKey: _b64decode(encoded));
  }

  /// base64url decode with the padding re-added (our stored key omits it,
  /// as JWTs do).
  List<int> _b64decode(String input) {
    final padded = input + ('=' * ((4 - input.length % 4) % 4));
    return base64Url.decode(padded);
  }

  /// Issues a signed JWT for this email and stores it as the session.
  /// The token — not an opaque random value — is what restoreSession()
  /// verifies on the next launch.
  Future<void> _createSession(String email) async {
    final jwt = await _jwt();
    final token = jwt.issue(
      subject: email,
      expiresIn: sessionDuration,
      extraClaims: const {'type': 'session'},
      issuedAt: _now(),
    );
    await _tokens.write(_sessionKey, token);
    await _tokens.write(_sessionEmailKey, email);
  }

  String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// SHA-256, iterated 1,000 times. Slow on purpose: it makes guessing
  /// passwords from a stolen hash file 1,000x slower. (A server would use
  /// bcrypt/argon2 — this is the honest local equivalent.)
  String _hashPassword(String password, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$password'));
    for (var i = 0; i < 999; i++) {
      digest = sha256.convert(digest.bytes);
    }
    return digest.toString();
  }

  bool _looksLikeEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
}
