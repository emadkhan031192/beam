package com.afzal.beam

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Handles the notification actions posted by TorchManager and ShakeService:
 * "Turn off" (torch) and "Turn off shake" (shake service).
 */
class TorchActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        TorchManager.init(context.applicationContext)
        when (intent.action) {
            ACTION_TORCH_OFF -> TorchManager.turnOff()
            ACTION_SHAKE_OFF ->
                context.applicationContext.stopService(
                    Intent(context.applicationContext, ShakeService::class.java)
                )
        }
    }

    companion object {
        const val ACTION_TORCH_OFF = "com.afzal.beam.action.TORCH_OFF"
        const val ACTION_SHAKE_OFF = "com.afzal.beam.action.SHAKE_OFF"
    }
}
