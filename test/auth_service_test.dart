import 'package:flutter_test/flutter_test.dart';
import 'package:self_improvement_app/services/auth_service.dart';

/// A clock the test controls, so lockout timing is deterministic.
class _FakeClock {
  DateTime now = DateTime(2026, 11, 25, 12, 0);
}

void main() {
  late AuthService auth;
  late _FakeClock clock;

  setUp(() {
    clock = _FakeClock();
    auth = AuthService(
      tokens: MemoryTokenStore(),
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
}
