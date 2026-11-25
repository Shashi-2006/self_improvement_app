// ─────────────────────────────────────────────────────────────────────────────
// LOCAL STORE — saves the whole app state on the phone as JSON.
//
// "Local-first" means: everything works without internet and without any
// account. The state lives in SharedPreferences (a small key-value store
// every phone app gets). When Firebase is wired up later (see
// firebase_backend.dart), the same JSON is also written to Firestore —
// the screens never need to know which one is active.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One key holds the whole app: simpler than one key per list, and the data
/// is small (a few KB). If the app ever grows to thousands of sessions, split
/// the keys — but not before then.
class LocalStore {
  static const _stateKey = 'self_improvement_app_state_v1';

  Future<Map<String, dynamic>?> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      // Corrupt save: start fresh rather than crash on launch.
      return null;
    }
  }

  Future<void> saveState(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, jsonEncode(json));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
  }
}
