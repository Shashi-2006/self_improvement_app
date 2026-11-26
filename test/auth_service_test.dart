import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:self_improvement_app/services/auth_service.dart';
import 'package:self_improvement_app/services/jwt_service.dart';

/// A clock the test controls, so lockout timing is deterministic.
class _FakeClock {
  DateTime now = DateTime(2026, 11, 25, 12, 0);
}

void main() {
  late AuthService auth;
  late MemoryTokenStore tokens;
  late _FakeClock clock;

  setUp(() {
    clock = _FakeClock();
    tokens = MemoryTokenStore();
    auth = AuthService(
      tokens: tokens,
      accounts: MemoryAccountStore(),
      now: () => clock.now,
    );
  });

  group('sign-up validation', () {
    test('rejects a bad email', () async {
      final result = await auth.signUp('not-an-email', 'longpassword123');
      expect(result.ok, false);
      expect(result.error, contains('email'));
    });

    test('rejects a short password (min 10 chars, IMS bar)', () async {
      final result = await auth.signUp('a@b.com', 'short');
      expect(result.ok, false);
      expect(result.error, contains('10 characters'));
    });

    test('rejects a duplicate email', () async {
      expect((await auth.signUp('a@b.com', 'longpassword123')).ok, true);
      final again = await auth.signUp('a@b.com', 'anotherpassword123');
      expect(again.ok, false);
      expect(again.error, contains('already exists'));
    });
  });

  group('sign-in + lockout', () {
    test('correct password signs in and restores the session', () async {
      await auth.signUp('a@b.com', 'longpassword123');
      await auth.signOut();
      final result = await auth.signIn('a@b.com', 'longpassword123');
      expect(result.ok, true);
      expect(await auth.restoreSession(), 'a@b.com');
    });

    test('wrong password fails without saying if the email exists', () async {
      await auth.signUp('a@b.com', 'longpassword123');
      final result = await auth.signIn('a@b.com', 'wrongpassword');
      expect(result.ok, false);
      expect(result.error, 'Wrong email or password.');
    });

    test('5 wrong attempts lock the account for 15 minutes', () async {
      await auth.signUp('a@b.com', 'longpassword123');
      for (var i = 0; i < 4; i++) {
        final r = await auth.signIn('a@b.com', 'wrongpassword');
        expect(r.ok, false);
        expect(r.lockedUntil, isNull);
      }
      final fifth = await auth.signIn('a@b.com', 'wrongpassword');
      expect(fifth.ok, false);
      expect(fifth.lockedUntil, isNotNull);

      // Even the RIGHT password is refused while locked.
      final right = await auth.signIn('a@b.com', 'longpassword123');
      expect(right.ok, false);
      expect(right.error, contains('Too many wrong attempts'));

      // 16 minutes later the lock has expired and sign-in works.
      clock.now = clock.now.add(const Duration(minutes: 16));
      final after = await auth.signIn('a@b.com', 'longpassword123');
      expect(after.ok, true);
    });

    test('signing out clears the session', () async {
      await auth.signUp('a@b.com', 'longpassword123');
      expect(await auth.restoreSession(), 'a@b.com');
      await auth.signOut();
      expect(await auth.restoreSession(), isNull);
    });
  });

  group('JWT sessions', () {
    test('the stored session is a signed JWT for the user', () async {
      await auth.signUp('a@b.com', 'longpassword123');
      final stored = await tokens.read('sia_session_token');
      expect(stored, isNotNull);
      expect(stored!.split('.').length, 3);

      // Rebuild the verifier from the stored per-device key, the way
      // restoreSession() does internally.
      final keyB64 = await tokens.read('sia_jwt_signing_key');
      expect(keyB64, isNotNull);
      final padded = keyB64! + ('=' * ((4 - keyB64.length % 4) % 4));
      final jwt = JwtService(signingKey: base64Url.decode(padded));
      final claims = jwt.verify(stored, now: clock.now);
      expect(claims, isNotNull);
      expect(claims!['sub'], 'a@b.com');
      expect(claims['type'], 'session');
    });

    test('a tampered stored token signs the user out', () async {
      await auth.signUp('a@b.com', 'longpassword123');
      expect(await auth.restoreSession(), 'a@b.com');
      await tokens.write('sia_session_token', 'x.y.z');
      expect(await auth.restoreSession(), isNull);
    });

    test('an expired session signs the user out', () async {
      await auth.signUp('a@b.com', 'longpassword123');
      expect(await auth.restoreSession(), 'a@b.com');
      // Sessions last 7 days; 8 days later the token is dead.
      clock.now = clock.now.add(const Duration(days: 8));
      expect(await auth.restoreSession(), isNull);
    });

    test('a session token paired with another email is rejected', () async {
      await auth.signUp('a@b.com', 'longpassword123');
      await tokens.write('sia_session_email', 'someone-else@b.com');
      expect(await auth.restoreSession(), isNull);
    });
  });
}
