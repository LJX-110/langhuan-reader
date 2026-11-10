package com.langhuan.reader.desktop

import androidx.compose.ui.graphics.toAwtImage
import com.langhuan.reader.desktop.desktopAppClassLoader
import com.langhuan.reader.help.image.decodeBytesSampled
import com.langhuan.reader.ui.compose.platform.DesktopThemeStoreProvider
import java.awt.Color
import java.awt.Dimension
import java.awt.Font
import java.awt.Graphics
import java.awt.Graphics2D
import java.awt.RenderingHints
import java.awt.image.BufferedImage
import javax.swing.JWindow

/**
 * 桌面端启动闪屏：固定品牌页，不再读取自定义欢迎图、显示开关与停留时长。
 *
 * 主窗口 [close] 前显示；内容为强调色竖线 + 竖排「琅嬛阁」+ 单色书阁图形。
 */
class DesktopSplashScreen(
    private val themeStore: DesktopThemeStoreProvider,
) {
    private var splashWindow: JWindow? = null

    /** 闪屏实际置为可见的时刻 (未显示为 0)。 */
    var shownAtMs: Long = 0L
        private set

    /** 自闪屏显示起算的毫秒数；尚未显示时返 [Long.MAX_VALUE]。 */
    fun elapsedSinceShow(): Long =
        if (shownAtMs == 0L) Long.MAX_VALUE else System.currentTimeMillis() - shownAtMs

    /** 基准画布 (内容布局/字号/图标尺寸的参照系), 实际窗口按屏幕比例缩放。 */
    companion object {
        const val BASE_WIDTH = 800
        const val BASE_HEIGHT = 480
        private const val SPLASH_DURATION_MS = 600L

        fun splashSizeFor(screen: Dimension): Dimension = Dimension(
            (screen.width / 2).coerceAtLeast(400),
            (screen.height / 2).coerceAtLeast(300),
        )
    }

    /**
     * 显示闪屏。由启动主线程同步调用；返回固定停留时长。
     */
    fun show(): Long {
        val accent = themeStore.accentColor
        val bgColor = themeStore.backgroundColor
        val accentRgb = Color(
            (accent.red * 255).toInt(),
            (accent.green * 255).toInt(),
            (accent.blue * 255).toInt(),
        )
        val bgRgb = Color(
            (bgColor.red * 255).toInt(),
            (bgColor.green * 255).toInt(),
            (bgColor.blue * 255).toInt(),
        )

        val screen = java.awt.Toolkit.getDefaultToolkit().screenSize
        val size = splashSizeFor(screen)
        val scale = minOf(
            size.width.toFloat() / BASE_WIDTH,
            size.height.toFloat() / BASE_HEIGHT,
        ).coerceAtMost(1f)

        val window = JWindow()
        window.size = size
        window.minimumSize = size
        window.maximumSize = size
        window.background = bgRgb
        window.contentPane.background = bgRgb
        window.contentPane.layout = null

        val content = SplashContent(
            accentColor = accentRgb,
            backgroundColor = bgRgb,
            width = size.width,
            height = size.height,
            scale = scale,
        )
        window.contentPane.add(content)
        content.bounds = java.awt.Rectangle(0, 0, size.width, size.height)

        window.setLocation(
            (screen.width - size.width) / 2,
            (screen.height - size.height) / 2,
        )
        window.isAlwaysOnTop = true
        window.isVisible = true
        shownAtMs = System.currentTimeMillis()
        splashWindow = window
        return SPLASH_DURATION_MS
    }

    /** 关闭闪屏。必须在 EDT 调用。幂等。 */
    fun close() {
        splashWindow?.let { w ->
            w.isVisible = false
            w.dispose()
        }
        splashWindow = null
    }

    private class SplashContent(
        private val accentColor: Color,
        private val backgroundColor: Color,
        private val width: Int,
        private val height: Int,
        private val scale: Float,
    ) : javax.swing.JPanel() {

        init {
            isOpaque = true
        }

        private val tintedIcon: BufferedImage? by lazy {
            runCatching {
                val decoded = desktopAppClassLoader
                    .getResourceAsStream("icon_read_book.png")
                    ?.use { decodeBytesSampled(it.readBytes(), 0) }?.toAwtImage()
                decoded?.let { tintImage(it, accentColor) }
            }.getOrNull()
        }

        override fun paintComponent(g: Graphics) {
            val g2d = g.create() as Graphics2D
            try {
                g2d.setRenderingHint(
                    RenderingHints.KEY_ANTIALIASING,
                    RenderingHints.VALUE_ANTIALIAS_ON,
                )
                g2d.setRenderingHint(
                    RenderingHints.KEY_TEXT_ANTIALIASING,
                    RenderingHints.VALUE_TEXT_ANTIALIAS_ON,
                )
                g2d.color = backgroundColor
                g2d.fillRect(0, 0, width, height)

                val text = "琅嬛阁"
                val fontSize = (56 * scale).toInt().coerceAtLeast(28)
                g2d.font = Font(Font.SERIF, Font.BOLD, fontSize)
                val fm = g2d.fontMetrics
                val lineHeight = (fontSize * 1.12f).toInt()
                val totalTextHeight = lineHeight * text.length
                val textTop = height / 2 - totalTextHeight / 2
                val textCenterX = width / 2

                // 强调色竖线
                g2d.color = accentColor
                val lineWidth = (4 * scale).toInt().coerceAtLeast(2)
                val lineX = textCenterX - (fontSize * 0.95f).toInt()
                g2d.fillRect(lineX, textTop, lineWidth, totalTextHeight)

                // 竖排书名
                text.forEachIndexed { index, ch ->
                    val textWidth = fm.stringWidth(ch.toString())
                    val x = textCenterX + (fontSize * 0.12f).toInt() - textWidth / 2
                    val y = textTop + index * lineHeight + fm.ascent
                    g2d.drawString(ch.toString(), x, y)
                }

                // 书阁图形
                val iconSize = (64 * scale).toInt().coerceAtLeast(32)
                tintedIcon?.let { icon ->
                    val iconX = (width - iconSize) / 2
                    val iconY = textTop + totalTextHeight + (28 * scale).toInt()
                    g2d.drawImage(icon, iconX, iconY, iconSize, iconSize, null)
                }
            } finally {
                g2d.dispose()
            }
        }

        /** 将图片染为目标颜色。 */
        private fun tintImage(image: BufferedImage, color: Color): BufferedImage {
            val result = BufferedImage(image.width, image.height, BufferedImage.TYPE_INT_ARGB)
            val g = result.createGraphics()
            try {
                g.drawImage(image, 0, 0, null)
                g.composite = java.awt.AlphaComposite.SrcIn
                g.color = color
                g.fillRect(0, 0, result.width, result.height)
            } finally {
                g.dispose()
            }
            return result
        }
    }
}
