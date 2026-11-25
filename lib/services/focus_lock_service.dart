// ─────────────────────────────────────────────────────────────────────────────
// FOCUS LOCK — "while the timer runs, unproductive apps stay off".
//
// THE FLOW (from the spec): before starting a timer the app asks
// "Do you want unproductive apps on or off during this session?"
//   * ON  -> no blocking, the timer just runs.
//   * OFF -> focus lock is on. While the timer runs, opening a blocked app
//            bounces the user back to the timer / focus screen.
//
// HOW IT WORKS ON ANDROID (real implementation, needs a real phone to fully
// verify — see the note at the bottom):
//  1. The app needs Usage Access permission (same as screen time).
//  2. A foreground check runs every 2 seconds through the Kotlin plugin:
//     it asks UsageStatsManager "which app is in the foreground right now?"
//  3. If the foreground app is in the blocked list, the plugin brings this
//     app back to the front, and Dart shows the "Blocked — back to focus"
//     message with the elapsed time.
//  4. Pausing the timer stops the checks (the lock lifts until Resume).
//     Finishing the timer stops them for good.
//
// ON WEB / WITHOUT PERMISSION: there is no way to watch other apps, so the
// app runs in DEMO mode — the Today screen shows the blocked-apps tray, and
// tapping a blocked app shows the same "blocked" message as a preview.
// The UI always says which mode it is in, so demo behaviour is never sold
// as real blocking.
//
// WHY NOT iOS: Apple does not let apps watch or block other apps. iOS gets
// the timer and a "focus mode" reminder, not real blocking. Android-first,
// as the spec says.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The result of one foreground check.
enum FocusCheck { ok, blockedAppInForeground, unavailable }

class FocusLockService {
  static const _channel =
      MethodChannel('self_improvement_app/focus');

  Timer? _watchTimer;
  void Function(String packageName)? onBlockedAppDetected;

  /// True while the lock is actively watching.
  bool get isWatching => _watchTimer != null;

  /// Start watching. [blockedPackages] are Android package names, e.g.
  /// "com.instagram.android". The check runs every 2 seconds.
  void startWatching(List<String> blockedPackages) {
    stopWatching();
    if (kIsWeb || blockedPackages.isEmpty) return;
    _watchTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final check = await checkForeground(blockedPackages);
      if (check == FocusCheck.blockedAppInForeground) {
        await bringAppToFront();
        // Which app? Ask the plugin for the name to show in the message.
        final name = await foregroundAppName();
        onBlockedAppDetected?.call(name ?? 'That app');
      }
    });
  }

  /// Stop watching — called on Pause (lock lifts until Resume) and on Finish.
  void stopWatching() {
    _watchTimer?.cancel();
    _watchTimer = null;
  }

  /// One check: is a blocked app in the foreground right now?
  Future<FocusCheck> checkForeground(List<String> blockedPackages) async {
    if (kIsWeb) return FocusCheck.unavailable;
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'checkForeground',
        {'blocked': blockedPackages},
      );
      if (result == null) return FocusCheck.unavailable;
      final blocked = result['blocked'] as bool? ?? false;
      return blocked ? FocusCheck.blockedAppInForeground : FocusCheck.ok;
    } on MissingPluginException {
      return FocusCheck.unavailable;
    } on PlatformException {
      return FocusCheck.unavailable;
    }
  }

  /// Ask Android to bring this app back to the front.
  Future<void> bringAppToFront() async {
    try {
      await _channel.invokeMethod<void>('bringToFront');
    } on MissingPluginException {
      // Web / no plugin — nothing to bring forward.
    } on PlatformException {
      // Best effort only.
    }
  }

  /// Human-readable name of the app currently in the foreground, if known.
  Future<String?> foregroundAppName() async {
    try {
      return await _channel.invokeMethod<String>('foregroundAppName');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  void dispose() => stopWatching();
}
