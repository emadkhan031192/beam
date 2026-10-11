package com.afzal.beam

import android.app.AlertDialog
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Quick Settings tile ("Beam"). Toggles the torch without opening the app.
 * Stays in sync through TorchManager's listener; long-press opens the app
 * (declared as an active tile in the manifest).
 */
class BeamTileService : TileService() {

    private val stateListener: (Map<String, Any>) -> Unit = {
        updateTile()
    }

    override fun onStartListening() {
        super.onStartListening()
        TorchManager.init(applicationContext)
        TorchManager.addListener(stateListener)
        updateTile()
    }

    override fun onStopListening() {
        TorchManager.removeListener(stateListener)
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()
        TorchManager.init(applicationContext)
        if (!TorchManager.isSupported()) {
            showNoFlashDialog()
            return
        }
        if (TorchManager.isOn()) {
            TorchManager.turnOff()
        } else {
            // Tile turns the light on from outside the app UI: the app will
            // not switch it off on destroy.
            TorchManager.turnOn(5, external = true)
        }
        updateTile()
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        val on = TorchManager.isOn()
        tile.state = if (on) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.subtitle = if (on) "On" else "Off"
        if (Build.VERSION.SDK_INT >= 30) {
            tile.stateDescription = if (on) "Flashlight on" else "Flashlight off"
        }
        tile.updateTile()
    }

    private fun showNoFlashDialog() {
        val dialog = AlertDialog.Builder(this)
            .setTitle("No flash")
            .setMessage("This device has no camera flash.")
            .setPositiveButton("OK", null)
            .create()
        showDialog(dialog)
    }
}
