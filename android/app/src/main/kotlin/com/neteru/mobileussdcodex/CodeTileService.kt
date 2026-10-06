package com.neteru.mobileussdcodex

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Quick Settings tile opening one code (the latest favorite, or the one
 * picked in the settings) on its run sheet, which still asks for
 * confirmation. The app saves the code with [save].
 */
class CodeTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile ?: return
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val label = prefs.getString(KEY_LABEL, null)
        tile.label = label ?: getString(R.string.tile_label)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) tile.subtitle = prefs.getString(KEY_CODE, null)
        tile.state = if (label != null) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        val intent = Intent(this, MainActivity::class.java)
            .setAction(Intent.ACTION_VIEW)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_ID, null)?.let { intent.putExtra(MainActivity.EXTRA_CODE_ID, it) }
        val open = {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }
        }
        if (isLocked) unlockAndRun(open) else open()
    }

    companion object {
        private const val PREFS = "quick_settings_tile"
        private const val KEY_ID = "id"
        private const val KEY_LABEL = "label"
        private const val KEY_CODE = "code"

        /** Saves the tile's code (null: none) and refreshes the tile. */
        fun save(context: Context, id: String?, label: String?, code: String?) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_ID, id)
                .putString(KEY_LABEL, label)
                .putString(KEY_CODE, code)
                .apply()
            requestListeningState(context, ComponentName(context, CodeTileService::class.java))
        }
    }
}
