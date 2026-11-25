package com.shashwat.self_improvement_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Registers the native side of screen time + focus lock
        // (UsageStatsManager). See UsageStatsPlugin.kt for the details.
        flutterEngine.plugins.add(UsageStatsPlugin())
    }
}
