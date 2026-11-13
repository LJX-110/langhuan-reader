package com.langhuan.reader.ui.route

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.sp
import com.langhuan.reader.constant.AppLog
import com.langhuan.reader.constant.AppPattern
import com.langhuan.reader.constant.DirUsage
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.help.config.AppConfigProviders
import com.langhuan.reader.help.config.PreferenceProviders
import com.langhuan.reader.help.config.ReadBookConfigProviders
import com.langhuan.reader.help.coroutine.IoDispatcher
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.ui.book.read.ReadBookEvents
import com.langhuan.reader.ui.book.read.ReadConfigChange
import com.langhuan.reader.ui.book.read.config.ChineseConverterSelectorDialog
import com.langhuan.reader.ui.book.read.config.FontItem
import com.langhuan.reader.ui.book.read.config.FontSelectDialog
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.root.FileFilter
import com.langhuan.reader.ui.root.PlatformCapabilityProviders
import com.langhuan.reader.ui.root.PlatformServiceProviders
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.other_folder
import com.langhuan.reader.ui.generated.resources.select_font_file
import org.jetbrains.compose.resources.stringResource

/**
 * 阅读排版的子面板（原「界面设置」底部弹窗拆出的独立入口）。
 *
 * 排版面板（[com.langhuan.reader.ui.book.read.ReadMenu] 的 STYLE 页）直接内嵌字号/字距/行距/段距
 * 滑条、纸色、翻页方式与主题；这里只保留滑条放不下的两项：
 * - [FontSelectDialogHost]：字体选择（含扫描/导入）
 * - [ChineseConverterDialogHost]：简繁转换
 *
 * 旧的样式预设色块行（微信读 / 预设 1..5 / 加号）已从阅读面板移除：
 * 背景与文字改由拟物纸样 + 12 套双色主题承担，样式数据仍保留在配置层。
 */

/** 字体选择弹窗（对照原 FontSelectDialog 入口：扫描字体 + 从文件导入 + 换扫描目录） */
@Composable
fun FontSelectDialogHost(onDismiss: () -> Unit) {
    val readBookConfig = ReadBookConfigProviders.get()
    val colors = AppTheme.colors
    val scope = rememberCoroutineScope()
    // 组合期捕获，供事件回调内写 fontFolder（CompositionLocal 只能在组合期读取）
    val prefs = PreferenceProviders.get()

    // 字体列表: 平台扫描注入 (对照 app 端 FontSelectDialog.loadFontFiles; 未实现端空列表)
    var fontItems by remember { mutableStateOf(emptyList<FontItem>()) }
    fun rescanFontItems() {
        scope.launch {
            fontItems = withContext(IoDispatcher) {
                PlatformCapabilityProviders.get().scanFontItems()
            }
        }
    }
    LaunchedEffect(Unit) {
        rescanFontItems()
    }

    fun selectFont(path: String) {
        readBookConfig.textFont = path
        readBookConfig.save()
        ReadBookEvents.postConfig(listOf(ReadConfigChange.STYLE, ReadConfigChange.LOAD_CONTENT))
    }

    // 字体选择对话框 (fontItems 由平台 [PlatformCapabilityProviders] 扫描注入)
    FontSelectDialog(
        fontItems = fontItems,
        curFontPath = readBookConfig.textFont,
        // 对照 app 端 FontSelectDialog: URLDecoder.decode(curFontPath) 后再取文件名 (P3)
        curFontName = urlDecodePath(readBookConfig.textFont).substringAfterLast('/'),
        onSelectFont = { path -> selectFont(path) },
        onSelectDefault = { selectFont("") },
        onDismiss = onDismiss,
        // "其它目录"/"选择字体文件"两个入口: 目录入口走平台目录选择能力 (Android SAF
        // OpenDocumentTree / iOS·鸿蒙文档选择器), 选完写 fontFolder pref + 重扫列表
        // (对照 app 端 FontSelectDialog.openFolder → AppConfig.fontFolder);
        // 文件入口把选定字体复制进内置字体目录 —— 字体在提供方根目录/云盘这类位置时,
        // 选目录选不到也读不稳, 复制进内置目录后扫描与加载都只认沙盒内文件
        topBarTrailing = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = stringResource(Res.string.select_font_file),
                    color = colors.primaryText,
                    fontSize = 15.sp,
                    modifier = Modifier
                        .clickable {
                            scope.launch {
                                val picked = withContext(IoDispatcher) {
                                    PlatformServiceProviders.get().files
                                        .pickFiles(FileFilter.Fonts)
                                }
                                if (picked.isEmpty()) return@launch
                                val (supported, unsupported) =
                                    picked.partition { it.name.matches(AppPattern.fontFileRegex) }
                                unsupported.forEach {
                                    Toasters.get().toast("不支持的文件: ${it.name}")
                                }
                                if (supported.isEmpty()) return@launch
                                val imported = withContext(IoDispatcher) {
                                    PlatformCapabilityProviders.get()
                                        .importPickedFontFiles(supported)
                                }
                                val failed = supported.size - imported.size
                                if (failed > 0) {
                                    AppLog.put("字体导入失败 $failed 个 (共 ${supported.size} 个)")
                                    Toasters.get().toast("$failed 个字体导入失败")
                                } else {
                                    Toasters.get().toast("已导入 ${imported.size} 个字体")
                                }
                                rescanFontItems()
                            }
                        }
                        .padding(vertical = DesignTokens.spacingDefault, horizontal = DesignTokens.spacingMd),
                )
                Text(
                    text = stringResource(Res.string.other_folder),
                    color = colors.primaryText,
                    fontSize = 15.sp,
                    modifier = Modifier
                        .clickable {
                            scope.launch {
                                val path = withContext(IoDispatcher) {
                                    PlatformServiceProviders.get().files.pickDirectory(DirUsage.Font)
                                } ?: return@launch
                                prefs.putString(PreferKey.fontFolder, path)
                                rescanFontItems()
                            }
                        }
                        .padding(vertical = DesignTokens.spacingDefault, horizontal = DesignTokens.spacingMd),
                )
            }
        },
    )
}

/** 简繁转换选择器（自包含：内部写 AppConfigProviders） */
@Composable
fun ChineseConverterDialogHost(onDismiss: () -> Unit) {
    ChineseConverterSelectorDialog(
        currentType = AppConfigProviders.get().chineseConverterType,
        onChanged = {
            ReadBookEvents.postConfig(listOf(ReadConfigChange.LOAD_CONTENT))
        },
        onDismiss = onDismiss,
    )
}

private fun urlDecodePath(input: String): String {
    if (input.isEmpty()) return input
    val bytes = ArrayList<Byte>(input.length)
    var i = 0
    while (i < input.length) {
        val c = input[i]
        if (c == '%' && i + 2 < input.length) {
            val h = hexValue(input[i + 1])
            val l = hexValue(input[i + 2])
            if (h >= 0 && l >= 0) {
                bytes.add(((h shl 4) or l).toByte())
                i += 3
                continue
            }
        }
        // 非 %XX 字符按 UTF-8 编码进字节流
        val cp = c.code
        when {
            cp < 0x80 -> bytes.add(cp.toByte())
            cp < 0x800 -> {
                bytes.add((0xC0 or (cp shr 6)).toByte())
                bytes.add((0x80 or (cp and 0x3F)).toByte())
            }

            else -> {
                bytes.add((0xE0 or (cp shr 12)).toByte())
                bytes.add((0x80 or ((cp shr 6) and 0x3F)).toByte())
                bytes.add((0x80 or (cp and 0x3F)).toByte())
            }
        }
        i++
    }
    return bytes.toByteArray().decodeToString()
}

private fun hexValue(c: Char): Int = when (c) {
    in '0'..'9' -> c - '0'
    in 'a'..'f' -> c - 'a' + 10
    in 'A'..'F' -> c - 'A' + 10
    else -> -1
}
