package com.langhuan.reader

import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Storage Access Framework folder picker + recursive TXT scan.
 *
 * The picker only returns a tree URI that survives process restarts via
 * persistable read permission. Files are copied into the app cache so the
 * existing TXT importer (which needs a real path) can parse them; callers
 * delete the copies after import.
 */
object FolderScanBridge {
    private const val CHANNEL = "langhuan/folder"
    private const val MAX_FILES = 500
    private const val MAX_DEPTH = 6

    /** Request code handled by [MainActivity.onActivityResult]. */
    const val REQUEST_CODE = 4210

    private var activity: MainActivity? = null
    private var channel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun attach(activity: MainActivity, messenger: BinaryMessenger) {
        this.activity = activity
        channel?.setMethodCallHandler(null)
        val next = MethodChannel(messenger, CHANNEL)
        channel = next
        next.setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFolder" -> pickFolder(result)
                "scanFolder" -> scanFolder(call.argument<String>("uri"), result)
                else -> result.notImplemented()
            }
        }
    }

    /** Called by [MainActivity] when the system folder picker returns. */
    fun onFolderPicked(uri: Uri?) {
        val result = pendingResult ?: return
        pendingResult = null
        if (uri == null) {
            result.success(null)
            return
        }
        try {
            activity?.contentResolver?.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            // Permission is not persistable on some providers; the picker
            // result still grants access for the current session.
        }
        result.success(mapOf("uri" to uri.toString(), "name" to displayName(uri)))
    }

    private fun pickFolder(result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.error("no_activity", "当前页面不可用", null)
            return
        }
        if (pendingResult != null) {
            result.error("busy", "上一次选择尚未结束", null)
            return
        }
        pendingResult = result
        try {
            act.startActivityForResult(
                Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                    )
                },
                REQUEST_CODE,
            )
        } catch (e: Exception) {
            pendingResult = null
            result.error("picker_failed", e.message, null)
        }
    }

    private fun scanFolder(treeUriValue: String?, result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.error("no_activity", "当前页面不可用", null)
            return
        }
        if (treeUriValue.isNullOrBlank()) {
            result.error("bad_args", "缺少文件夹 URI", null)
            return
        }
        val treeUri = Uri.parse(treeUriValue)
        executor.execute {
            try {
                val rootId = DocumentsContract.getTreeDocumentId(treeUri)
                val cacheDir = File(act.cacheDir, "folder_scan")
                cacheDir.deleteRecursively()
                cacheDir.mkdirs()
                val files = mutableListOf<Map<String, Any>>()
                walk(act, treeUri, rootId, cacheDir, files, 0)
                val payload = mapOf(
                    "name" to (displayName(treeUri) ?: "文件夹"),
                    "files" to files,
                )
                mainHandler.post { result.success(payload) }
            } catch (e: SecurityException) {
                mainHandler.post {
                    result.error("permission_lost", "文件夹读取权限已失效，请重新选择", null)
                }
            } catch (e: Exception) {
                mainHandler.post { result.error("scan_failed", e.message, null) }
            }
        }
    }

    private fun walk(
        act: MainActivity,
        treeUri: Uri,
        documentId: String,
        cacheDir: File,
        out: MutableList<Map<String, Any>>,
        depth: Int,
    ) {
        if (depth > MAX_DEPTH || out.size >= MAX_FILES) return
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, documentId)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        act.contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            while (cursor.moveToNext() && out.size < MAX_FILES) {
                val id = cursor.getString(0) ?: continue
                val name = cursor.getString(1) ?: id
                val mime = cursor.getString(2)
                if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    walk(act, treeUri, id, cacheDir, out, depth + 1)
                    continue
                }
                if (!name.endsWith(".txt", ignoreCase = true)) continue
                val fileUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, id)
                val target = File(
                    cacheDir,
                    UUID.nameUUIDFromBytes(fileUri.toString().toByteArray()).toString() + ".txt",
                )
                val copied = act.contentResolver.openInputStream(fileUri)?.use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                    target.length()
                }
                if (copied == null || copied <= 0L) {
                    target.delete()
                    continue
                }
                out.add(
                    mapOf(
                        "name" to name,
                        "path" to target.absolutePath,
                        "uri" to fileUri.toString(),
                        "size" to copied,
                    ),
                )
            }
        }
    }

    private fun displayName(uri: Uri): String? {
        val act = activity ?: return null
        val documentUri = DocumentsContract.buildDocumentUriUsingTree(
            uri,
            DocumentsContract.getTreeDocumentId(uri),
        )
        return act.contentResolver.query(
            documentUri,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
    }
}
