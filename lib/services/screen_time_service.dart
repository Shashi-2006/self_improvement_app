// ─────────────────────────────────────────────────────────────────────────────
// SCREEN TIME — reads the phone's real app-usage numbers on Android.
//
// HOW IT WORKS (Android): Android itself keeps a count of how long each app
// was on screen — UsageStatsManager. The app asks for "Usage Access"
// permission, then a small Kotlin plugin (android/.../UsageStatsPlugin.kt)
// reads that count. The app NEVER sees what you did inside Instagram, only
// how long it was open.
//
// ON WEB / WITHOUT PERMISSION: the platform channel throws, and this service
// falls back to clearly-marked DEMO data (the researched averages from the
// spec: Instagram 3h, YouTube 1h28m, TikTok 1h12m...). The UI always shows
// "Demo data" in that case, so nobody mistakes it for real tracking.
//
// CLASSIFICATION RULES (from the spec — the important bit):
//  * Clear defaults: short-video / social / games -> non-productive;
//    study / coding / notes / learning -> productive.
//  * AMBIGUOUS APPS ARE NEVER HARD-CODED: LinkedIn, WhatsApp, YouTube and
//    the browser can be productive or not depending on HOW they are used.
//    They always start as "Unclassified / You decide", and the user tags them.
//  * SPIKE PROMPT: if an unclassified app's usage keeps rising day by day,
//    the app asks once: "This app is taking more of your time — is it
//    productive or non-productive for you?" It also says if the app looks
//    like a game. It never nags every day.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';

/// Apps that are always ambiguous — the same app, used two ways.
/// These are NEVER given a fixed tag by the app. If you add a new social or
/// messaging app here, think twice: it belongs here only when its use can be
/// either productive or not.
const Set<String> ambiguousPackages = {
  'com.linkedin.android', // jobs / learning vs scrolling
  'com.whatsapp', // work / study chat vs random chatting
  'com.google.android.youtube', // lectures vs Shorts
  'com.android.chrome', // research vs doom-scrolling
  'org.mozilla.firefox',
  'com.instagram.android', // kept ambiguous only when the user says so
};

/// Clear defaults for apps whose purpose is (almost) always one thing.
UsageTag defaultTagFor(String packageName) {
  const productive = {
    'com.duolingo',
    'com.leetcode',
    'com.github.android',
    'com.microsoft.office.onenote',
    'com.google.android.keep',
    'com.notion.id',
    'com.coursera.android',
    'org.khanacademy.android',
  };
  const nonProductive = {
    'com.zhiliaoapp.musically', // TikTok
    'com.ss.android.ugc.trill', // TikTok (alt)
    'com.snapchat.android',
    'com.facebook.katana',
    'com.twitter.android',
    'com.reddit.frontpage',
    'com.netflix.mediaclient',
  };
  if (productive.contains(packageName)) return UsageTag.productive;
  if (nonProductive.contains(packageName)) return UsageTag.nonProductive;
  if (ambiguousPackages.contains(packageName)) return UsageTag.unclassified;
  // Unknown app? Don't guess — the user decides.
  return UsageTag.unclassified;
}

/// Demo data, used on web and whenever Usage Access is not granted.
/// The numbers are the researched daily averages from the spec, clearly
/// labelled as demo wherever they are shown.
List<AppUsageEntry> demoUsage() => [
      AppUsageEntry(
        appName: 'Instagram',
        packageName: 'com.instagram.android',
        minutesToday: 180,
        minutesYesterday: 160,
        minutesLastWeek: 1050,
        tag: UsageTag.nonProductive,
        dailyLimitMinutes: 60,
      ),
      AppUsageEntry(
        appName: 'YouTube',
        packageName: 'com.google.android.youtube',
        minutesToday: 88,
        minutesYesterday: 95,
        minutesLastWeek: 650,
        tag: UsageTag.unclassified, // lectures vs Shorts — user decides
        dailyLimitMinutes: 60,
      ),
      AppUsageEntry(
        appName: 'TikTok',
        packageName: 'com.zhiliaoapp.musically',
        minutesToday: 72,
        minutesYesterday: 68,
        minutesLastWeek: 480,
        tag: UsageTag.nonProductive,
      ),
      AppUsageEntry(
        appName: 'WhatsApp',
        packageName: 'com.whatsapp',
        minutesToday: 64,
        minutesYesterday: 58,
        minutesLastWeek: 420,
        tag: UsageTag.unclassified, // work chat vs random chat
      ),
      AppUsageEntry(
        appName: 'LinkedIn',
        packageName: 'com.linkedin.android',
        minutesToday: 52,
        minutesYesterday: 40,
        minutesLastWeek: 300,
        tag: UsageTag.unclassified, // jobs / learning vs scrolling
      ),
      AppUsageEntry(
        appName: 'LeetCode',
        packageName: 'com.leetcode',
        minutesToday: 38,
        minutesYesterday: 45,
        minutesLastWeek: 280,
        tag: UsageTag.productive,
      ),
    ];

/// Top wasting apps for the weekly orbit recap: the non-productive apps,
/// biggest first. (The mockup's orbit shows Instagram, YouTube, TikTok,
/// Snapchat and games.)
List<AppUsageEntry> topWastingApps(List<AppUsageEntry> all) {
  final wasting = all
      .where((e) => e.tag == UsageTag.nonProductive)
      .toList()
    ..sort((a, b) => b.minutesToday.compareTo(a.minutesToday));
  return wasting.take(5).toList();
}

/// Should the app ask "is this productive or non-productive for you?"
/// Fires only when an unclassified app's usage is rising day by day —
/// today clearly above yesterday AND above its recent average. Never daily.
bool shouldAskAboutSpike(AppUsageEntry entry) {
  if (entry.tag != UsageTag.unclassified) return false;
  if (entry.minutesToday < 30) return false; // too small to care about
  final rising = entry.minutesToday > entry.minutesYesterday * 1.2;
  final aboveAverage = entry.minutesToday > entry.minutesLastWeek / 7 * 1.2;
  return rising && aboveAverage;
}

/// Talks to the Android plugin. Returns null when the platform cannot
/// answer (web, iOS, permission denied) — the caller then uses demo data.
class ScreenTimeService {
  static const _channel =
      MethodChannel('self_improvement_app/usage');

  /// True when the app may read UsageStats (Android only).
  Future<bool> hasUsagePermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasUsagePermission');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the Android "Usage Access" settings screen. The user grants the
  /// permission there — the app cannot grant it for them.
  Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod<void>('openUsageSettings');
    } on MissingPluginException {
      // Web / iOS: nothing to open. The UI explains this.
    } on PlatformException {
      // Ignore — the settings screen is best-effort.
    }
  }

  /// Today's per-app usage from the phone, sorted biggest first.
  /// Returns null when real data is unavailable.
  Future<List<AppUsageEntry>?> fetchTodayUsage() async {
    if (kIsWeb) return null;
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getTodayUsage');
      if (raw == null) return null;
      final entries = <AppUsageEntry>[];
      for (final item in raw) {
        final map = Map<String, dynamic>.from(item as Map);
        final package = map['package'] as String? ?? '';
        entries.add(AppUsageEntry(
          appName: map['appName'] as String? ?? package,
          packageName: package,
          minutesToday: (map['minutes'] as int? ?? 0),
          minutesYesterday: 0,
          minutesLastWeek: 0,
          tag: defaultTagFor(package),
          isGame: map['isGame'] as bool? ?? false,
        ));
      }
      entries.sort((a, b) => b.minutesToday.compareTo(a.minutesToday));
      return entries.take(5).toList();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
