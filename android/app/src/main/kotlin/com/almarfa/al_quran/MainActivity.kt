package com.almarfa.al_quran

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts a small MethodChannel so the Sunnah-reminders feature can ask the user to
 * exempt the app from battery optimization — the single biggest cause of dropped
 * scheduled notifications on aggressive OEMs (OnePlus/Oppo/Xiaomi). Exact alarms
 * (SCHEDULE_EXACT_ALARM) are handled by flutter_local_notifications directly.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.almarfa.al_quran/reminders"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())
                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    // ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS shows a one-tap system dialog.
    // SuppressLint("BatteryLife"): intentional — a time-specific reminder app is a
    // legitimate use; falls back to the settings list if the dialog is unavailable.
    @SuppressLint("BatteryLife")
    private fun requestIgnoreBatteryOptimizations() {
        if (isIgnoringBatteryOptimizations()) return
        try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                },
            )
        } catch (e: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (_: Exception) {
                // Best-effort — nothing more we can do from here.
            }
        }
    }
}
