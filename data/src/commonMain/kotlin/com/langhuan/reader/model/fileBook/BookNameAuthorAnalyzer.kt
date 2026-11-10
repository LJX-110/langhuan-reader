package com.langhuan.reader.model.fileBook

import com.langhuan.reader.constant.AppLog
import com.langhuan.reader.constant.AppPattern
import com.langhuan.reader.help.book.BookHelpShared
import com.langhuan.reader.model.script.JsBindings
import com.langhuan.reader.model.script.JsEngines
import com.langhuan.reader.utils.GSON
import com.langhuan.reader.utils.fromJsonObject

/**
 * 从文件名分析书名与作者 (原 app 端 `FileBook.analyzeNameAuthor` + `nameAuthorPatterns` 下沉)。
 *
 * 原实现依赖 java.util.regex.Pattern (→ [Regex]) 与 AppConfig.bookImportFileName
 * (→ [analyzeNameAuthor] 的 importFileNameJs 参数, 由各端 accessor 传入)。
 */
object BookNameAuthorAnalyzer {

    private val nameAuthorPatterns = arrayOf(
        Regex("(.*?)《([^《》]+)》.*?作者：(.*)"),
        Regex("(.*?)《([^《》]+)》(.*)"),
        Regex("(^)(.+) 作者：(.+)$"),
        Regex("(^)(.+) by (.+)$")
    )

    /**
     * @param importFileNameJs 用户自定义的文件名解析 JS (app 端传 `AppConfig.bookImportFileName`,
     *   未提供该配置的端传 null, 直接走正则分支)
     */
    fun analyzeNameAuthor(fileName: String, importFileNameJs: String? = null): Pair<String, String> {
        val tempFileName = fileName.substringBeforeLast(".")
        var name = ""
        var author = ""
        importFileNameJs?.takeIf { it.isNotBlank() }?.let { jsCode ->
            try {
                //在用户脚本后添加捕获author、name的代码，只要脚本中author、name有值就会被捕获
                val js = "$jsCode\nJSON.stringify({author:author,name:name})"
                //在脚本中定义如何分解文件名成书名、作者名
                val jsonStr = JsEngines.get().run {
                    val bindings = JsBindings().apply { put("src", tempFileName) }
                    eval(js, bindings)
                }.toString()
                val bookMess = GSON.fromJsonObject<Map<String, String>>(jsonStr).getOrNull()
                name = bookMess?.get("name") ?: ""
                author = bookMess?.get("author")?.takeIf { it.length != tempFileName.length } ?: ""
            } catch (e: Exception) {
                AppLog.put("执行导入文件名规则出错\n${e.message}", e)
            }
        }
        if (name.isBlank()) {
            for (pattern in nameAuthorPatterns) {
                pattern.find(tempFileName)?.run {
                    name = groupValues[2]
                    author = BookHelpShared.formatBookAuthor(groupValues[1] + groupValues[3])
                    return Pair(name, author)
                }
            }
            name = tempFileName
                .replace(AppPattern.nameRegex, "")
                .trim()
            author = BookHelpShared.formatBookAuthor(tempFileName.replace(name, ""))
                .takeIf { it.length != tempFileName.length } ?: ""
        }
        return Pair(name, author)
    }
}
