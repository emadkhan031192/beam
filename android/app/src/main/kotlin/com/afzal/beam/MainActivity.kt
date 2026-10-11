package com.afzal.beam

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts the Flutter UI and bridges the platform channels:
 *
 * - MethodChannel `com.afzal.beam/torch`
 * - EventChannel  `com.afzal.beam/torch_events` (torch state incl. conflicts)
 * - EventChannel  `com.afzal.beam/battery` (sticky battery percent)
 *
 * Fast-path: when launched from the "Light on" home-screen shortcut, the
 * torch is turned on natively in onCreate, before the Flutter engine's first
 * frame. Dart consumes the flag via `consumeShortcutLightOn`.
 */
class MainActivity : FlutterActivity() {

    private var torchSink: EventChannel.EventSink? = null
    private var batterySink: EventChannel.EventSink? = null

    /** Set when the activity was launched from the "Light on" shortcut. */
    private var pendingShortcutLightOn: Boolean = false

    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != Intent.ACTION_BATTERY_CHANGED) return
            batterySink?.success(batteryPercent(intent))
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Init the torch layer as early as possible (cold-start budget).
        TorchManager.init(applicationContext)
        handleLightOnIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleLightOnIntent(intent)
    }

    /** Shortcut fast-path: light the torch natively, before the first frame. */
    private fun handleLightOnIntent(intent: Intent?) {
        if (intent?.action == ACTION_LIGHT_ON && TorchManager.isSupported()) {
            pendingShortcutLightOn = true
            // external=false: the app is open showing the lit state, so a
            // destroyed app still switches the light off (never left on).
            TorchManager.turnOn(5, external = false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        TorchManager.eventListener = { event ->
            runOnUiThread { torchSink?.success(event) }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "com.afzal.beam/torch"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(TorchManager.isSupported())
                "on" -> {
                    val level = (call.argument<Int>("level") ?: 5)
                    val external = (call.argument<Boolean>("external") ?: false)
                    TorchManager.turnOn(level, external)
                    result.success(null)
                }
                "off" -> {
                    TorchManager.turnOff()
                    result.success(null)
                }
                "setLevel" -> {
                    TorchManager.setLevel(call.argument<Int>("level") ?: 5)
                    result.success(null)
                }
                "startStrobe" -> {
                    TorchManager.startStrobe(call.argument<Int>("hz") ?: 6)
                    result.success(null)
                }
                "startSos" -> {
                    TorchManager.startSos()
                    result.success(null)
                }
                "stop" -> {
                    TorchManager.stop()
                    result.success(null)
                }
                "getState" -> result.success(TorchManager.getState())
                "getApkSizeMb" -> result.success(apkSizeMb())
                "consumeShortcutLightOn" -> {
                    val v = pendingShortcutLightOn
                    pendingShortcutLightOn = false
                    result.success(v)
                }
                "setAutoOffMinutes" -> {
                    TorchManager.setAutoOffMinutes(
                        call.argument<Int>("minutes") ?: 0
                    )
                    result.success(null)
                }
                "requestNotificationPermission" ->
                    result.success(requestNotificationPermission())
                "openBatterySettings" -> {
                    result.success(openBatterySettings())
                }
                "setShakeEnabled" -> {
                    setShakeEnabled(call.argument<Boolean>("enabled") ?: false)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.afzal.beam/torch_events",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                torchSink = events
                // Push the current state immediately so the UI never waits.
                events.success(TorchManager.getState())
            }

            override fun onCancel(arguments: Any?) {
                torchSink = null
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger, "com.afzal.beam/battery"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                batterySink = events
                // The sticky broadcast gives the current level right away.
                val sticky = registerReceiver(
                    null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                )
                if (sticky != null) events.success(batteryPercent(sticky))
                registerReceiver(
                    batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                )
            }

            override fun onCancel(arguments: Any?) {
                batterySink = null
                try {
                    unregisterReceiver(batteryReceiver)
                } catch (_: IllegalArgumentException) {
                    // Already unregistered.
                }
            }
        })
    }

    private fun batteryPercent(intent: Intent): Int {
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        return if (level >= 0 && scale > 0) (level * 100) / scale else -1
    }

    private fun apkSizeMb(): Double {
        return try {
            File(packageCodePath).length() / (1024.0 * 1024.0)
        } catch (_: Exception) {
            0.0
        }
    }

    /**
     * Requests POST_NOTIFICATIONS on Android 13+. Returns true when the
     * permission is already granted; otherwise the request is fired and the
     * caller proceeds (a denied permission only hides the notification).
     */
    private fun requestNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < 33) return true
        val permission = Manifest.permission.POST_NOTIFICATIONS
        val granted = ContextCompat.checkSelfPermission(this, permission) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) {
            ActivityCompat.requestPermissions(
                this, arrayOf(permission), REQUEST_NOTIFICATIONS
            )
        }
        return granted
    }

    private fun openBatterySettings(): Boolean {
        return try {
            startActivity(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun setShakeEnabled(enabled: Boolean) {
        val intent = Intent(this, ShakeService::class.java)
        if (enabled) {
            // POST_NOTIFICATIONS is requested by Dart right before this call.
            ContextCompat.startForegroundService(this, intent)
        } else {
            stopService(intent)
        }
    }

    override fun onDestroy() {
        // Never leave the torch on by accident: unless it was turned on from
        // the tile / notification / shake, switching the app off kills it.
        // (Rotation does not destroy with singleTask + configChanges, and
        // backgrounding alone doesn't finish the activity.)
        TorchManager.onAppDestroy(isFinishing)
        TorchManager.eventListener = null
        super.onDestroy()
    }

    companion object {
        const val ACTION_LIGHT_ON = "com.afzal.beam.action.LIGHT_ON"
        private const val REQUEST_NOTIFICATIONS = 9001
    }
}
