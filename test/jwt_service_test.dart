import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_improvement_app/services/jwt_service.dart';

/// A fixed key, so the tests are deterministic. In the app the key is
/// generated per device and kept in secure storage — never hardcoded.
final _testKey = utf8.encode('test-signing-key-32-bytes-long!!');

/// A second key, standing in for "someone else's secret".
final _otherKey = utf8.encode('a-different-key-32-bytes-long!!!');

void main() {
  late JwtService jwt;
  late DateTime now;

  setUp(() {
    jwt = JwtService(signingKey: _testKey);
    now = DateTime(2026, 11, 26, 20, 0);
  });

  group('issue + verify round-trip', () {
    test('a token issued now verifies and carries its claims', () {
      final token = jwt.issue(
        subject: 'a@b.com',
        extraClaims: const {'type': 'session'},
        issuedAt: now,
      );
      final claims = jwt.verify(token, now: now);
      expect(claims, isNotNull);
      expect(claims!['sub'], 'a@b.com');
      expect(claims['type'], 'session');
      expect(claims['iat'], now.millisecondsSinceEpoch ~/ 1000);
      expect(
        claims['exp'],
        now.millisecondsSinceEpoch ~/ 1000 + const Duration(days: 7).inSeconds,
      );
    });

    test('three dot-separated parts, base64url with no padding', () {
      final token = jwt.issue(subject: 'a@b.com', issuedAt: now);
      final parts = token.split('.');
      expect(parts.length, 3);
      expect(token.contains('='), false);
      expect(token.contains('+') || token.contains('/'), false);
    });

    test('a custom expiry is honoured', () {
      final token = jwt.issue(
        subject: 'a@b.com',
        expiresIn: const Duration(minutes: 30),
        issuedAt: now,
      );
      final claims = jwt.verify(token, now: now);
      expect(
        claims!['exp'],
        now.millisecondsSinceEpoch ~/ 1000 + 30 * 60,
      );
    });
  });

  group('tampering is rejected', () {
    test('changing one character of the payload breaks the signature', () {
      final token = jwt.issue(subject: 'a@b.com', issuedAt: now);
      final parts = token.split('.');
      // Flip the first payload character to a different valid base64url char.
      final tamperedPayload =
          (parts[1][0] == 'A' ? 'B' : 'A') + parts[1].substring(1);
      final tampered = '${parts[0]}.$tamperedPayload.${parts[2]}';
      expect(jwt.verify(tampered, now: now), isNull);
    });

    test('changing the signature is rejected', () {
      final token = jwt.issue(subject: 'a@b.com', issuedAt: now);
      final parts = token.split('.');
      final tamperedSig =
          (parts[2][0] == 'A' ? 'B' : 'A') + parts[2].substring(1);
      expect(
        jwt.verify('${parts[0]}.${parts[1]}.$tamperedSig', now: now),
        isNull,
      );
    });

    test('a token signed with a different key is rejected', () {
      final other = JwtService(signingKey: _otherKey);
      final token = other.issue(subject: 'a@b.com', issuedAt: now);
      expect(jwt.verify(token, now: now), isNull);
    });

    test('swapping in a different subject keeps the old signature — rejected', () {
      // Build a payload for another user and attach the original signature.
      final token = jwt.issue(subject: 'a@b.com', issuedAt: now);
      final parts = token.split('.');
      final forgedPayload = JwtService(signingKey: _testKey)
          .issue(subject: 'victim@b.com', issuedAt: now)
          .split('.')[1];
      expect(
        jwt.verify('${parts[0]}.$forgedPayload.${parts[2]}', now: now),
        isNull,
      );
    });
  });

  group('expiry', () {
    test('an expired token is rejected', () {
      final token = jwt.issue(
        subject: 'a@b.com',
        expiresIn: const Duration(days: 7),
        issuedAt: now,
      );
      final eightDaysLater = now.add(const Duration(days: 8));
      expect(jwt.verify(token, now: eightDaysLater), isNull);
    });

    test('a token is still valid just before expiry', () {
      final token = jwt.issue(
        subject: 'a@b.com',
        expiresIn: const Duration(days: 7),
        issuedAt: now,
      );
      final almostExpired = now.add(const Duration(days: 6, hours: 23));
      expect(jwt.verify(token, now: almostExpired), isNotNull);
    });
  });

  group('malformed tokens', () {
    test('two parts is not a JWT', () {
      expect(jwt.verify('abc.def', now: now), isNull);
    });

    test('empty string is rejected', () {
      expect(jwt.verify('', now: now), isNull);
    });

    test('garbage base64 is rejected', () {
      expect(jwt.verify('!!!.@@@.###', now: now), isNull);
    });

    test('a correctly signed token without exp is rejected', () {
      // Hand-build a token with a VALID signature but no exp claim, using
      // the same key — verify() must still refuse it, because a token
      // that never expires must never be trusted.
      String b64(Map<String, dynamic> json) => base64Url
          .encode(utf8.encode(jsonEncode(json)))
          .replaceAll('=', '');
      final header = b64({'alg': 'HS256', 'typ': 'JWT'});
      final payload = b64({'sub': 'a@b.com', 'iat': 1});
      final signingInput = '$header.$payload';
      final digest = Hmac(sha256, _testKey).convert(utf8.encode(signingInput));
      final signature =
          base64Url.encode(digest.bytes).replaceAll('=', '');
      expect(jwt.verify('$signingInput.$signature', now: now), isNull);
    });
  });

  group('decodeUnverified — read, never trust', () {
    test('reads the payload of a valid token', () {
      final token = jwt.issue(subject: 'a@b.com', issuedAt: now);
      expect(jwt.decodeUnverified(token)!['sub'], 'a@b.com');
    });

    test('still reads a tampered token — that is why it is untrusted', () {
      final token = jwt.issue(subject: 'a@b.com', issuedAt: now);
      final parts = token.split('.');
      final tampered = '${parts[0]}.${parts[1]}.tamperedsignature';
      // verify() rejects it…
      expect(jwt.verify(tampered, now: now), isNull);
      // …but decodeUnverified() still shows the claims. Callers must
      // never use this result for access decisions.
      expect(jwt.decodeUnverified(tampered)!['sub'], 'a@b.com');
    });
  });
}
