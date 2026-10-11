package com.afzal.beam

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import kotlin.math.sqrt

/**
 * Foreground service that toggles the flashlight on two quick shakes.
 *
 * Runs as a `specialUse` foreground service (see the manifest for the
 * justification string). Posts a quiet low-priority notification with a
 * "Turn off shake" action.
 *
 * Note: some phones stop delivering sensor events when the screen is off;
 * the settings screen says so plainly instead of promising otherwise.
 */
class ShakeService : Service(), SensorEventListener {

    private var sensorManager: SensorManager? = null

    /** Timestamp of the first shake of a potential pair. */
    private var firstShakeAt: Long = 0L

    override fun onCreate() {
        super.onCreate()
        TorchManager.init(applicationContext)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val accelerometer =
            sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (accelerometer != null) {
            sensorManager?.registerListener(
                this, accelerometer, SensorManager.SENSOR_DELAY_UI
            )
        }
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        sensorManager?.unregisterListener(this)
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_ACCELEROMETER) return
        val x = event.values[0] / SensorManager.GRAVITY_EARTH
        val y = event.values[1] / SensorManager.GRAVITY_EARTH
        val z = event.values[2] / SensorManager.GRAVITY_EARTH
        val g = sqrt(x * x + y * y + z * z)
        if (g < SHAKE_G_THRESHOLD) return

        val now = SystemClock.elapsedRealtime()
        if (firstShakeAt != 0L && now - firstShakeAt <= SHAKE_WINDOW_MS) {
            firstShakeAt = 0L
            toggleTorch()
        } else {
            firstShakeAt = now
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun toggleTorch() {
        if (!TorchManager.isSupported()) return
        if (TorchManager.isOn()) {
            TorchManager.turnOff()
        } else {
            // Shake turns the light on from outside the app UI.
            TorchManager.turnOn(5, external = true)
        }
    }

    private fun buildNotification(): android.app.Notification {
        ensureChannel()
        val offIntent = Intent(this, TorchActionReceiver::class.java).apply {
            action = TorchActionReceiver.ACTION_SHAKE_OFF
        }
        val offPending = PendingIntent.getBroadcast(
            this, 0, offIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Shake to toggle is on")
            .setContentText("Two quick shakes switch the flashlight")
            .setOngoing(true)
            .setShowWhen(false)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Turn off shake",
                offPending,
            )
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Shake to toggle",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Shows while shake-to-toggle is listening"
                    setShowBadge(false)
                }
            )
        }
    }

    companion object {
        private const val CHANNEL_ID = "beam_shake"
        private const val NOTIFICATION_ID = 1002

        /** A shake counts when total acceleration exceeds ~2.6 g. */
        private const val SHAKE_G_THRESHOLD = 2.6

        /** Two shakes must land inside this window to toggle. */
        private const val SHAKE_WINDOW_MS = 900L
    }
}
