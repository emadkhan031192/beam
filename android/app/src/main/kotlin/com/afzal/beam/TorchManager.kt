package com.afzal.beam

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import androidx.core.app.NotificationCompat
import kotlin.math.roundToInt

/**
 * The entire native torch layer. Flutter talks to it through the
 * `com.afzal.beam/torch` MethodChannel (see MainActivity); state changes are
 * pushed to Dart through [eventListener].
 *
 * Uses CameraManager.setTorchMode(), which needs no CAMERA permission.
 * Strobe and SOS run on a dedicated HandlerThread, never on Dart timers.
 */
object TorchManager {

    // -- Modes ---------------------------------------------------------------
    const val MODE_STEADY = "steady"
    const val MODE_STROBE = "strobe"
    const val MODE_SOS = "sos"

    // -- SOS timing (standard Morse, 150 ms unit) ------------------------------
    private const val SOS_UNIT = 150L

    // -- Notifications --------------------------------------------------------
    private const val TORCH_CHANNEL_ID = "beam_torch"
    private const val TORCH_NOTIFICATION_ID = 1001

    private var appContext: Context? = null
    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null
    private var maxStrength: Int = 1
    private var torchCallbackRegistered = false

    private var isOn: Boolean = false
    private var mode: String = MODE_STEADY
    private var level: Int = 5 // app step 1..5
    private var onSinceMs: Long = 0L

    /** True when the light was turned on from outside the app UI
     * (tile, notification action, shake, shortcut). The app then leaves the
     * torch alone when it is destroyed. */
    private var externalControl: Boolean = false

    private var autoOffMinutes: Int = 0
    private val mainHandler = Handler(Looper.getMainLooper())
    private var autoOffRunnable: Runnable? = null

    private var patternThread: HandlerThread? = null
    private var patternHandler: Handler? = null

    private val listeners = java.util.concurrent.CopyOnWriteArrayList<(Map<String, Any>) -> Unit>()

    /** Set by MainActivity to forward events to the Dart EventChannel. */
    var eventListener: ((Map<String, Any>) -> Unit)? = null

    // -- Lifecycle ------------------------------------------------------------

    @Synchronized
    fun init(context: Context) {
        if (appContext != null) return
        val app = context.applicationContext
        appContext = app
        val cm = app.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        cameraManager = cm
        cameraId = findFlashCameraId(cm)
        maxStrength = readMaxStrength(cm, cameraId)
        registerTorchCallback(cm)
    }

    private fun findFlashCameraId(cm: CameraManager): String? {
        return try {
            cm.cameraIdList.firstOrNull { id ->
                val c = cm.getCameraCharacteristics(id)
                c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true &&
                    c.get(CameraCharacteristics.LENS_FACING) ==
                    CameraCharacteristics.LENS_FACING_BACK
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun readMaxStrength(cm: CameraManager, id: String?): Int {
        if (id == null || Build.VERSION.SDK_INT < 33) return 1
        return try {
            val c = cm.getCameraCharacteristics(id)
            c.get(CameraCharacteristics.FLASH_INFO_STRENGTH_MAXIMUM_LEVEL) ?: 1
        } catch (_: Exception) {
            1
        }
    }

    private fun registerTorchCallback(cm: CameraManager) {
        if (torchCallbackRegistered) return
        try {
            cm.registerTorchCallback(mainHandler::post, object : CameraManager.TorchCallback() {
                override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
                    if (cameraId != this@TorchManager.cameraId) return
                    if (patternHandler != null) {
                        // Strobe/SOS toggles the LED itself on this thread; the
                        // resulting callbacks are expected noise from our own
                        // pattern, not an external state change. Never stop the
                        // pattern here — doing so killed strobe on its first
                        // off-toggle. (Camera conflicts still arrive via
                        // onTorchModeUnavailable below.)
                        return
                    }
                    // The callback is the source of truth: confirm real state.
                    if (enabled != isOn) {
                        isOn = enabled
                        if (!enabled) {
                            stopPatternLocked()
                            cancelNotification()
                            cancelAutoOff()
                        }
                    }
                    emit()
                }

                override fun onTorchModeUnavailable(cameraId: String) {
                    if (cameraId != this@TorchManager.cameraId) return
                    // Another app grabbed the camera: turn the UI off.
                    isOn = false
                    mode = MODE_STEADY
                    stopPatternLocked()
                    cancelNotification()
                    cancelAutoOff()
                    emit(conflict = true)
                }
            })
            torchCallbackRegistered = true
        } catch (_: Exception) {
            // Very old devices; state events still work, callback just won't.
        }
    }

    // -- Public API (called from MainActivity's MethodChannel handler) --------

    fun isSupported(): Boolean = cameraId != null

    fun isOn(): Boolean = isOn

    fun brightnessSupported(): Boolean =
        Build.VERSION.SDK_INT >= 33 && maxStrength > 1

    /** App step (1..5) -> native strength level (1..maxStrength).
     * Mirrors Dart's mapStepToNativeLevel; step 5 is always the maximum. */
    fun stepToNative(step: Int): Int {
        val s = step.coerceIn(1, 5)
        if (maxStrength <= 1) return 1
        return (((s - 1) * (maxStrength - 1)) / 4.0).roundToInt()
            .coerceIn(0, maxStrength - 1) + 1
    }

    fun turnOn(step: Int, external: Boolean = false) {
        val id = cameraId ?: return
        stopPatternLocked()
        level = step.coerceIn(1, 5)
        mode = MODE_STEADY
        externalControl = external
        applyTorch(id, on = true, step = level)
        isOn = true
        onSinceMs = System.currentTimeMillis()
        showNotification()
        scheduleAutoOff()
        emit()
    }

    fun turnOff() {
        val id = cameraId ?: return
        stopPatternLocked()
        applyTorch(id, on = false, step = level)
        isOn = false
        mode = MODE_STEADY
        externalControl = false
        cancelNotification()
        cancelAutoOff()
        emit()
    }

    fun setLevel(step: Int) {
        val id = cameraId ?: return
        level = step.coerceIn(1, 5)
        if (isOn && mode == MODE_STEADY) {
            applyTorch(id, on = true, step = level)
        }
        emit()
    }

    fun startStrobe(hz: Int, external: Boolean = false) {
        val id = cameraId ?: return
        stopPatternLocked()
        val rate = hz.coerceIn(1, 20)
        mode = MODE_STROBE
        externalControl = external
        isOn = true
        onSinceMs = System.currentTimeMillis()
        showNotification()
        scheduleAutoOff()
        startPatternThread()
        val halfPeriod = (1000L / (rate * 2)).coerceAtLeast(25L)
        val nativeLevel = stepToNative(level)
        var lit = false
        val toggle = object : Runnable {
            override fun run() {
                lit = !lit
                setTorchRaw(id, lit, nativeLevel)
                patternHandler?.postDelayed(this, halfPeriod)
            }
        }
        // Kick off immediately so the first flash is instant.
        patternHandler?.post(toggle)
        emit()
    }

    fun startSos(external: Boolean = false) {
        val id = cameraId ?: return
        stopPatternLocked()
        mode = MODE_SOS
        externalControl = external
        isOn = true
        onSinceMs = System.currentTimeMillis()
        showNotification()
        scheduleAutoOff()
        startPatternThread()
        val pattern = sosPattern() // [onMs, offMs, ...], repeats
        val nativeLevel = stepToNative(level)
        var index = 0
        var lit = true
        // Start lit immediately.
        setTorchRaw(id, true, nativeLevel)
        val step = object : Runnable {
            override fun run() {
                val duration = pattern[index % pattern.size]
                index++
                lit = !lit
                setTorchRaw(id, lit, nativeLevel)
                patternHandler?.postDelayed(this, duration)
            }
        }
        patternHandler?.postDelayed(step, pattern[0])
        emit()
    }

    /** Stops any pattern and turns the torch off. */
    fun stop() = turnOff()

    fun setAutoOffMinutes(minutes: Int) {
        autoOffMinutes = minutes.coerceAtLeast(0)
        scheduleAutoOff()
    }

    fun getState(): Map<String, Any> = mapOf(
        "on" to isOn,
        "mode" to mode,
        "level" to level,
        "brightnessSupported" to brightnessSupported(),
        "maxStrength" to maxStrength,
        "onSinceMs" to onSinceMs,
        "conflict" to false,
    )

    /** Called from MainActivity.onDestroy. */
    fun onAppDestroy(isFinishing: Boolean) {
        if (isFinishing && !externalControl && isOn) {
            turnOff()
        }
    }

    fun addListener(l: (Map<String, Any>) -> Unit) = listeners.add(l)
    fun removeListener(l: (Map<String, Any>) -> Unit) = listeners.remove(l)

    // -- Internals ------------------------------------------------------------

    private fun applyTorch(id: String, on: Boolean, step: Int) {
        setTorchRaw(id, on, stepToNative(step))
    }

    private fun setTorchRaw(id: String, on: Boolean, nativeLevel: Int) {
        val cm = cameraManager ?: return
        try {
            if (on && Build.VERSION.SDK_INT >= 33 && nativeLevel > 1) {
                cm.turnOnTorchWithStrengthLevel(id, nativeLevel)
            } else {
                cm.setTorchMode(id, on)
            }
        } catch (_: Exception) {
            // Camera busy or gone; the TorchCallback will report the truth.
        }
    }

    private fun startPatternThread() {
        stopPatternLocked()
        val thread = HandlerThread("BeamTorch")
        thread.start()
        patternThread = thread
        patternHandler = Handler(thread.looper)
    }

    private fun stopPatternLocked() {
        patternHandler?.removeCallbacksAndMessages(null)
        patternHandler = null
        patternThread?.quitSafely()
        patternThread = null
    }

    /** SOS ··· −−− ··· with standard timing, as [onMs, offMs, ...]. */
    private fun sosPattern(): LongArray {
        val u = SOS_UNIT
        val dot = u
        val dash = 3 * u
        val intra = u
        val letterGap = 3 * u
        val wordGap = 7 * u
        val out = mutableListOf<Long>()
        fun letter(vararg elements: Long) {
            elements.forEachIndexed { i, e ->
                out.add(e)
                out.add(if (i == elements.lastIndex) letterGap else intra)
            }
        }
        letter(dot, dot, dot)
        letter(dash, dash, dash)
        letter(dot, dot, dot)
        out[out.lastIndex] = wordGap
        return out.toLongArray()
    }

    private fun scheduleAutoOff() {
        cancelAutoOff()
        if (autoOffMinutes > 0 && isOn) {
            val r = Runnable { turnOff() }
            autoOffRunnable = r
            mainHandler.postDelayed(r, autoOffMinutes * 60L * 1000L)
        }
    }

    private fun cancelAutoOff() {
        autoOffRunnable?.let { mainHandler.removeCallbacks(it) }
        autoOffRunnable = null
    }

    private fun ensureTorchChannel() {
        val ctx = appContext ?: return
        if (Build.VERSION.SDK_INT < 26) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(TORCH_CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    TORCH_CHANNEL_ID,
                    "Flashlight",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Shows while the flashlight is on"
                    setShowBadge(false)
                }
            )
        }
    }

    private fun showNotification() {
        val ctx = appContext ?: return
        ensureTorchChannel()
        val offIntent = Intent(ctx, TorchActionReceiver::class.java).apply {
            action = TorchActionReceiver.ACTION_TORCH_OFF
        }
        val offPending = PendingIntent.getBroadcast(
            ctx, 0, offIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val openIntent = ctx.packageManager
            .getLaunchIntentForPackage(ctx.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val openPending = openIntent?.let {
            PendingIntent.getActivity(
                ctx, 1, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val notification: Notification = NotificationCompat.Builder(ctx, TORCH_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Flashlight is on")
            .setContentText("Tap Turn off to switch it off")
            .setOngoing(true)
            .setShowWhen(false)
            .setContentIntent(openPending)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Turn off",
                offPending,
            )
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        try {
            nm.notify(TORCH_NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS denied; the torch still works.
        }
    }

    private fun cancelNotification() {
        val ctx = appContext ?: return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(TORCH_NOTIFICATION_ID)
    }

    private fun emit(conflict: Boolean = false) {
        val base = getState().toMutableMap()
        base["conflict"] = conflict
        val snapshot: Map<String, Any> = base
        eventListener?.invoke(snapshot)
        listeners.forEach { it(snapshot) }
    }
}
