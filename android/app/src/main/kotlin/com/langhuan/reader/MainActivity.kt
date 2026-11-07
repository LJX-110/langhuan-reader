package com.langhuan.reader

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.Charset

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EngineBridge.attach(this, flutterEngine.dartExecutor.binaryMessenger)
        FolderScanBridge.attach(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "langhuan/charset",
        ).setMethodCallHandler { call, result ->
            if (call.method != "decode") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
                val charset = call.argument<String>("charset") ?: "UTF-8"
                result.success(String(bytes, Charset.forName(charset)))
            } catch (e: Exception) {
                result.error("decode_failed", e.message, null)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != FolderScanBridge.REQUEST_CODE) return
        FolderScanBridge.onFolderPicked(
            if (resultCode == Activity.RESULT_OK) data?.data else null,
        )
    }
}
