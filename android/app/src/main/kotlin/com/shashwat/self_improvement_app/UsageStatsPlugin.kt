package com.shashwat.self_improvement_app

// ─────────────────────────────────────────────────────────────────────────────
// UsageStatsPlugin — the native Android side of screen time + focus lock.
//
// WHAT IT DOES (in plain words):
//  * Android itself counts how long each app was on screen. This plugin asks
//    Android for that count (UsageStatsManager) and hands it to Dart.
//  * It can also ask "which app is in the foreground RIGHT NOW?" — that is
//    how focus lock knows a blocked app was opened.
//  * It can bring this app back to the front when a blocked app is detected.
//
// PERMISSIONS (the user grants these in Android Settings — the app cannot
// grant them for itself):
//  * PACKAGE_USAGE_STATS ("Usage Access") — needed for both features.
//    Without it, every method below returns "not available" and Dart falls
//    back to clearly-labelled demo data.
//
// PRIVACY: this code reads only HOW LONG apps were open. It never reads
// what you did inside them, and it never sends anything anywhere — the
// numbers stay on the phone (and, later, in the user's own Firestore).
// ─────────────────────────────────────────────────────────────────────────────

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class UsageStatsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var context: Context
    private var usageChannel: MethodChannel? = null
    private var focusChannel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        usageChannel = MethodChannel(binding.binaryMessenger, "self_improvement_app/usage")
        usageChannel?.setMethodCallHandler(this)
        focusChannel = MethodChannel(binding.binaryMessenger, "self_improvement_app/focus")
        focusChannel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        usageChannel?.setMethodCallHandler(null)
        focusChannel?.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasUsagePermission" -> result.success(hasUsagePermission())
            "openUsageSettings" -> {
                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(null)
            }
            "getTodayUsage" -> {
                if (!hasUsagePermission()) {
                    result.success(null) // Dart falls back to demo data.
                    return
                }
                result.success(todayUsage())
            }
            "checkForeground" -> {
                @Suppress("UNCHECKED_CAST")
                val blocked = (call.argument<List<String>>("blocked") ?: emptyList()).toSet()
                val foreground = foregroundPackage()
                result.success(mapOf("blocked" to (foreground != null && blocked.contains(foreground))))
            }
            "foregroundAppName" -> {
                val pkg = foregroundPackage()
                result.success(pkg?.let { appLabel(it) })
            }
            "bringToFront" -> {
                val intent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                if (intent != null) context.startActivity(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Today's per-app screen time, biggest first (top 5 kept by Dart). */
    private fun todayUsage(): List<Map<String, Any>> {
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val startOfDay = now - (now % 86_400_000L) // midnight UTC; good enough for v1
        val stats = manager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY, startOfDay, now,
        ) ?: return emptyList()
        val pm = context.packageManager
        return stats
            .filter { it.totalTimeInForeground > 60_000 } // ignore < 1 min
            .sortedByDescending { it.totalTimeInForeground }
            .map { stat ->
                val minutes = (stat.totalTimeInForeground / 60_000).toInt()
                val isGame = try {
                    val info = pm.getApplicationInfo(stat.packageName, 0)
                    info.category == ApplicationInfo.CATEGORY_GAME
                } catch (e: PackageManager.NameNotFoundException) {
                    false
                }
                mapOf<String, Any>(
                    "package" to stat.packageName,
                    "appName" to appLabel(stat.packageName),
                    "minutes" to minutes,
                    "isGame" to isGame,
                )
            }
    }

    /** The package currently in the foreground, from the usage EVENTS log. */
    private fun foregroundPackage(): String? {
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = manager.queryEvents(now - 10_000, now) ?: return null
        var lastPackage: String? = null
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                lastPackage = event.packageName
            }
        }
        return lastPackage
    }

    private fun appLabel(packageName: String): String {
        return try {
            val info = context.packageManager.getApplicationInfo(packageName, 0)
            context.packageManager.getApplicationLabel(info).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            packageName
        }
    }
}
