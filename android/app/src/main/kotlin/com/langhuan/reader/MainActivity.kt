package com.langhuan.reader

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.Charset

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
}
