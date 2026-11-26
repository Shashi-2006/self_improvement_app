// ─────────────────────────────────────────────────────────────────────────────
// JWT — JSON Web Tokens, implemented from scratch (HS256).
//
// WHAT A JWT IS: three base64url parts joined by dots —
//   header.payload.signature
//   * header:    {"alg":"HS256","typ":"JWT"} — how it is signed.
//   * payload:   the claims — who (sub), when issued (iat), when it dies
//                (exp), plus anything the app adds (here: type=session).
//   * signature: HMAC-SHA256(secret, "header.payload") — proves the first
//                two parts were not changed after signing. Anyone can READ
//                a JWT (the payload is only encoded, not encrypted); only
//                someone with the secret can WRITE a valid one.
//
// HOW THE APP USES IT: AuthService issues one JWT per sign-in (subject =
// the email, 7-day expiry) and stores it in secure storage. On startup,
// restoreSession() VERIFIES the signature and the expiry before trusting
// it. A tampered or expired token is rejected and the user is signed out.
//
// THE HONEST LIMITS — read before trusting this:
//   * The signing key lives ON THIS DEVICE (secure storage, generated once
//     per device). So a JWT here proves "this token was issued on this
//     phone and not tampered with since" — it does NOT prove identity to a
//     server. A stolen JWT is usable until it expires, which is why the
//     expiry is short and sign-out deletes the stored copy.
//   * The real verification happens when Firebase lands: Firebase Auth
//     issues ID tokens (which are JWTs) and the Admin SDK / Firestore
//     rules verify them server-side with Google's keys. This file is the
//     stepping stone — same three-part shape, same verify-before-trust
//     rule — so the concepts transfer directly.
//   * Never put secrets in a payload. The payload is readable by anyone
//     who sees the token.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// How much clock difference to tolerate when checking expiry, so a phone
/// whose clock is a minute off does not get signed out for no reason.
const Duration _jwtLeeway = Duration(seconds: 60);

/// A small, dependency-free JWT implementation (HS256 only).
///
/// The signing key is supplied by the caller — AuthService keeps it in
/// secure storage. This class never stores a key itself, so tests can pass
/// a fixed key and the app can rotate its key by deleting the stored one.
class JwtService {
  JwtService({required List<int> signingKey})
      : _signingKey = List<int>.unmodifiable(signingKey);

  final List<int> _signingKey;

  /// Issues a signed token.
  ///
  /// [subject] is the `sub` claim (here: the user's email). [extraClaims]
  /// are merged into the payload. [issuedAt] exists so tests can control
  /// time; the app passes its own clock.
  String issue({
    required String subject,
    Duration expiresIn = const Duration(days: 7),
    Map<String, dynamic> extraClaims = const {},
    DateTime? issuedAt,
  }) {
    final now = issuedAt ?? DateTime.now();
    final iat = now.millisecondsSinceEpoch ~/ 1000;
    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final payload = <String, dynamic>{
      'sub': subject,
      'iat': iat,
      'exp': iat + expiresIn.inSeconds,
      ...extraClaims,
    };
    final encodedHeader = _b64encode(utf8.encode(jsonEncode(header)));
    final encodedPayload = _b64encode(utf8.encode(jsonEncode(payload)));
    final signingInput = '$encodedHeader.$encodedPayload';
    final signature = _sign(signingInput);
    return '$signingInput.$signature';
  }

  /// Verifies a token and returns its claims, or null when it must not be
  /// trusted: wrong shape, bad base64, bad signature, or expired.
  ///
  /// Verification is the whole point — NEVER trust a token that has only
  /// been decoded. See [decodeUnverified].
  Map<String, dynamic>? verify(String token, {DateTime? now}) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final encodedHeader = parts[0];
    final encodedPayload = parts[1];
    final signature = parts[2];
    if (encodedHeader.isEmpty || encodedPayload.isEmpty || signature.isEmpty) {
      return null;
    }

    // 1. The signature must match — this is what proves the token was
    //    issued with our key and not edited afterwards.
    final expected = _sign('$encodedHeader.$encodedPayload');
    if (!_constantTimeEquals(signature, expected)) return null;

    // 2. The header must say HS256 — never accept a token that claims a
    //    different algorithm (the classic "alg: none" attack).
    final header = _decodeJson(encodedHeader);
    if (header == null || header['alg'] != 'HS256') return null;

    // 3. The payload must parse and carry an expiry that has not passed.
    final payload = _decodeJson(encodedPayload);
    if (payload == null) return null;
    final exp = payload['exp'];
    if (exp is! num) return null;
    final nowSeconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    if (nowSeconds > exp + _jwtLeeway.inSeconds) return null;

    return payload;
  }

  /// Reads the payload WITHOUT verifying the signature. Useful for
  /// debugging ("what does this token claim?") and nothing else — the
  /// result must never be trusted for access. If you need to trust it,
  /// use [verify].
  Map<String, dynamic>? decodeUnverified(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    return _decodeJson(parts[1]);
  }

  // ── Signing ──────────────────────────────────────────────────────────────

  String _sign(String signingInput) {
    final hmac = Hmac(sha256, _signingKey);
    final digest = hmac.convert(utf8.encode(signingInput));
    return _b64encode(digest.bytes);
  }

  /// Compares two strings in constant time, so an attacker cannot learn
  /// how many leading characters of a signature are right by timing the
  /// check. (A plain `==` stops at the first wrong character.)
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  // ── Encoding helpers ─────────────────────────────────────────────────────

  /// base64url WITHOUT padding — the JWT standard. Dart's encoder adds
  /// `=` padding, which JWTs omit.
  String _b64encode(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  List<int>? _b64decode(String input) {
    try {
      // Re-add the padding Dart's decoder expects.
      final padded = input + ('=' * ((4 - input.length % 4) % 4));
      return base64Url.decode(padded);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic>? _decodeJson(String encoded) {
    final bytes = _b64decode(encoded);
    if (bytes == null) return null;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } on FormatException {
      return null;
    }
  }
}
