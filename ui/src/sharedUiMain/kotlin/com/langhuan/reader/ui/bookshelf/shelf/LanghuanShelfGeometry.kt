package com.langhuan.reader.ui.bookshelf.shelf

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos

/**
 * 3D 书架的纯几何（从参考实现 `archive_shelf_geometry.dart` 逐项移植）。
 *
 * 一本书 = 书脊平面 + 顶面 + 封面平面，三者共用同一组物理顶点：
 * 书脊沿 x 轴轻轻切变（shear）立在台上，封面沿深度向量 (depthX, depthY) 斜投影展开；
 * 被「抽出」的那本沿深度向量向左上推出，再整体抬起。
 *
 * 这里只有数字和算式，绘制与命中测试共用同一份来源。
 * 所有常量按 dp 设计（与参考一致），像素换算统一交给 [LanghuanShelfMetrics]。
 */
object LanghuanShelfGeometry {
    /** 斜投影的深度向量：向右 .66、向上 .30（屏幕 y 轴朝下，所以为负）。 */
    const val depthX = .66f
    const val depthY = -.30f

    /** 书脊顶边相对底边右移的比例：整排书立在同一个斜面上。 */
    const val spineShear = .10f

    /** 行内弧线：远端每格下沉的斜率与曲率，以及封顶距离。 */
    const val rowStep = 2.5f
    const val rowCurve = .45f
    const val rowMaxDistance = 7f

    /** 抽出波的半径（单位：格位），再远的书完全收回。 */
    const val waveRadius = 1.48f

    /** 相邻格位的横向步长 = 书脊宽 + 这道缝。 */
    const val pitchGap = 11f

    /** 抽出行程与抬起量（相对封面宽 / 书身高度）。 */
    const val pullRatio = .84f
    const val liftRatio = .60f

    fun spineFor(width: Float): Float = (width * .043f).coerceIn(14f, 18f)

    fun pitchFor(width: Float): Float = spineFor(width) + pitchGap

    fun coverFor(width: Float): Float = (width * .32f).coerceIn(100f, 128f)

    /** 书身高度：封面图（118:166）加上下两道档案栏位。 */
    fun bodyHeight(cover: Float): Float = (cover - 20f) * 166f / 118f + 54f

    /** 一本静止的书在屏幕上的横向宽度：书脊 + 封面投影（注意含 [depthX]）。 */
    fun footprint(spine: Float, cover: Float): Float = spine + cover * depthX

    fun pullDistance(cover: Float): Float = cover * pullRatio

    /** 静止书顶到行框顶端的距离。 */
    fun baseY(cover: Float, height: Float): Float =
        -cover * depthY + height * .60f + 12f

    /** 行框总高度：静止站位 + 书身 + 底部留白。 */
    fun rowHeight(cover: Float, height: Float): Float =
        baseY(cover, height) + height + 60f

    /** 行内弧线：以中心为最低点，向两侧收，远端封顶。 */
    fun railY(distance: Float): Float {
        val d = distance.coerceIn(-rowMaxDistance, rowMaxDistance)
        return d * rowStep + d * d * rowCurve
    }

    /** 抽出波权重：中心为 1，[waveRadius] 处为 0，中间按 cos² 收口。 */
    fun wave(distance: Float): Float {
        val d = abs(distance)
        if (d >= waveRadius) return 0f
        val value = cos(d / waveRadius * PI.toFloat() / 2f)
        return value * value
    }

    /** 抽出位移：沿深度向量推出，再整体抬起（相对静止位置）。 */
    fun extractionX(cover: Float, weight: Float): Float =
        -pullDistance(cover) * weight * (1.24f - .24f * weight) * depthX

    fun extractionY(cover: Float, height: Float, weight: Float): Float {
        val pull = pullDistance(cover) * weight * (1.24f - .24f * weight)
        val lift = weight * weight * (3f - 2f * weight)
        return -pull * depthY - height * liftRatio * lift
    }
}

/**
 * 某个视口宽度下解析出来的一套书架尺寸（单位：px）。
 *
 * [LanghuanShelfGeometry] 的常量按 dp 设计，这里统一按 [density] 换算成像素，
 * 避免高密度屏上整排书缩成一条细线。
 */
class LanghuanShelfMetrics(val viewport: Float, val density: Float = 1f) {
    private val viewportDp: Float = viewport / density
    private val spineDp: Float = LanghuanShelfGeometry.spineFor(viewportDp)
    private val coverDp: Float = LanghuanShelfGeometry.coverFor(viewportDp)
    private val bodyDp: Float = LanghuanShelfGeometry.bodyHeight(coverDp)

    val spineW: Float = spineDp * density
    val coverW: Float = coverDp * density
    val pitch: Float = LanghuanShelfGeometry.pitchFor(viewportDp) * density

    /** 书身高度（封面本身的高度；顶面在封面顶边之上）。 */
    val bodyH: Float = bodyDp * density

    val footprint: Float = LanghuanShelfGeometry.footprint(spineW, coverW)
    val pullDistance: Float = LanghuanShelfGeometry.pullDistance(coverW)

    /** 静止书顶在行框内的纵向位置。 */
    val baseY: Float = LanghuanShelfGeometry.baseY(coverDp, bodyDp) * density

    /** 行框总高度（含抽出上浮与大片留白）。 */
    val rowHeight: Float = LanghuanShelfGeometry.rowHeight(coverDp, bodyDp) * density

    /** 封面面板里的图片尺寸（面板上下各留一行档案位）。 */
    val coverImageW: Float = coverW - 20f * density
    val coverImageH: Float = coverImageW * 166f / 118f

    /** 行首：让完全抽出的那本书正好落在视口正中。 */
    val rowStart: Float =
        viewport / 2f - footprint / 2f +
            pullDistance * LanghuanShelfGeometry.depthX

    /** 行内弧线的纵向像素量（坡度按 dp 设计）。 */
    fun railY(distance: Float): Float =
        LanghuanShelfGeometry.railY(distance) * density

    /** 抽出位移（像素，相对静止位置）。 */
    fun extractionX(weight: Float): Float =
        LanghuanShelfGeometry.extractionX(coverW, weight)

    fun extractionY(weight: Float): Float =
        LanghuanShelfGeometry.extractionY(coverW, bodyH, weight)
}
