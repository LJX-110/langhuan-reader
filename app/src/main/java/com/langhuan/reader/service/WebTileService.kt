package com.langhuan.reader.service

import android.app.Dialog
import android.app.ForegroundServiceStartNotAllowedException
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.view.WindowManager.BadTokenException
import com.langhuan.reader.R
import com.langhuan.reader.constant.IntentAction
import com.langhuan.reader.utils.printOnDebug
import com.langhuan.reader.web.WebServerManager


/**
 * web服务快捷开关
 */
class WebTileService : TileService() {

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            when (intent?.action) {
                IntentAction.start -> qsTile?.run {
                    state = Tile.STATE_ACTIVE
                    updateTile()
                }

                IntentAction.stop -> qsTile?.run {
                    state = Tile.STATE_INACTIVE
                    updateTile()
                }
            }
        } catch (e: Exception) {
            e.printOnDebug()
        }
        return super.onStartCommand(intent, flags, startId)
    }

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.run {
            state = if (WebServerManager.isRun) {
                Tile.STATE_ACTIVE
            } else {
                Tile.STATE_INACTIVE
            }
            updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        if (WebServerManager.isRun) {
            WebService.stop(this)
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                val dialog = Dialog(this, R.style.AppTheme_Transparent)
                dialog.setOnShowListener {
                    try {
                        WebService.startForeground(this)
                    } catch (e: ForegroundServiceStartNotAllowedException) {
                        e.printStackTrace()
                    }
                    dialog.dismiss()
                }
                try {
                    showDialog(dialog)
                } catch (e: BadTokenException) {
                    e.printStackTrace()
                }
            } else {
                WebService.start(this)
            }
        }
    }

}