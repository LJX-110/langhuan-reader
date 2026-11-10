package com.langhuan.reader.ui.bookshelf.shelf

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos

/**
 * 3D 书架的纯几何（从琅嬛阁 `shelf_geometry.dart` 逐项移植）。
 *
 * 整排书共用一套斜投影：书脊是一块切变过的平行四边形，封面从书脊顶边
 * 沿深度向量向后铺开，被「抽出」的那本沿同一深度向量向左上推出并抬起。
 * 这里只有数字和算式，绘制与命中测试共用同一份来源。
 */
object LanghuanShelfGeometry {
    /** 斜投影的深度向量：向右 .66、向上 .30（屏幕 y 轴朝下，所以为负）。 */
    const val depthX = .66f
    const val depthY = -.30f

    /** 书脊顶边相对底边右移的比例，让整排书立在同一个斜面上。 */
    const val spineShear = .10f

    /** 相邻格位的横向步长 = 书脊宽 + 这道缝。 */
    const val slotGap = 11f

    /** 抽出波的半径（单位：格位）。再远的书完全收回，只当书脊排。 */
    const val waveRadius = 1.48f

    /** 完全抽出时的行程（相对封面宽）与抬起量（相对书高）。 */
    const val pullRatio = .84f
    const val liftRatio = .60f

    /** 行框顶端到静止书顶的距离（相对书高），以及行框底部留白。 */
    const val seatRatio = .60f
    const val rowPadding = 44f

    /** 行内弧线：远端每格下沉的斜率与曲率，以及封顶距离。 */
    const val rowStep = 2.5f
    const val rowCurve = .45f
    const val rowMaxDistance = 7f

    fun spineWidth(width: Float): Float = (width * .043f).coerceIn(14f, 18f)

    fun pitch(width: Float): Float = spineWidth(width) + slotGap

    fun coverWidth(width: Float): Float = (width * .32f).coerceIn(100f, 128f)

    /** 书身高度：封面图（118:166）加上下两道档案栏位。 */
    fun bodyHeight(cover: Float): Float = (cover - 20f) * 166f / 118f + 54f

    /** 一本静止的书从书脊左边到封面右边、在屏幕上的横向宽度。 */
    fun footprint(spine: Float, cover: Float): Float = spine + cover * depthX

    /** 顶面在书脊顶边之上撑起的高度。 */
    fun topInset(cover: Float): Float = -cover * depthY

    /** 静止时书顶在行框内的纵向位置：书坐在行框下半部，抽出时才上浮。 */
    fun seatY(height: Float): Float = height * seatRatio + 12f

    /** 抽出波权重：中心为 1，[waveRadius] 处为 0，中间按 cos² 收口。 */
    fun wave(distance: Float): Float {
        val d = abs(distance)
        if (d >= waveRadius) return 0f
        val value = cos(d / waveRadius * PI.toFloat() / 2f)
        return value * value
    }

    /** 抽出行程：越靠中心拉得越远，末段稍微收力，避免相邻两本撞在一起。 */
    fun pull(cover: Float, weight: Float): Float =
        cover * pullRatio * weight * (1.24f - .24f * weight)

    /** 抬起量：smoothstep，书是被「抬起」而不是沿斜线平移。 */
    fun lift(height: Float, weight: Float): Float =
        height * liftRatio * (weight * weight * (3f - 2f * weight))

    /** 抽出位移（相对静止位置）：沿深度向量推出，再整体抬起。 */
    fun extractionX(cover: Float, weight: Float): Float =
        -pull(cover, weight) * depthX

    fun extractionY(cover: Float, height: Float, weight: Float): Float =
        -pull(cover, weight) * depthY - lift(height, weight)

    /** 行内弧线：以中心为最低点，向两侧对称下沉，远端封顶。 */
    fun railY(distance: Float): Float {
        val d = distance.coerceIn(-rowMaxDistance, rowMaxDistance)
        return d * rowStep + d * d * rowCurve
    }
}

/**
 * 某个视口宽度下解析出来的一套书架尺寸（单位：px）。
 *
 * [LanghuanShelfGeometry] 里的常量是按 dp 设计的（与参考实现一致），
 * 这里统一按 [density] 换算成像素，避免高密度屏上整排书缩成一条细线。
 */
class LanghuanShelfMetrics(val viewport: Float, val density: Float = 1f) {
    private val viewportDp: Float = viewport / density
    private val spineDp: Float = LanghuanShelfGeometry.spineWidth(viewportDp)
    private val coverDp: Float = LanghuanShelfGeometry.coverWidth(viewportDp)

    val spineW: Float = spineDp * density
    val coverW: Float = coverDp * density
    val bodyH: Float = LanghuanShelfGeometry.bodyHeight(coverDp) * density
    val pitch: Float = (spineDp + LanghuanShelfGeometry.slotGap) * density
    val footprint: Float = LanghuanShelfGeometry.footprint(spineW, coverW)
    val topInset: Float = LanghuanShelfGeometry.topInset(coverW)

    /** 书身高度（封面本身；顶面画在它上方）。 */
    val volumeH: Float = topInset + bodyH + LanghuanShelfGeometry.spineShear * spineW

    /** 静止书顶在行框内的纵向位置。 */
    val seatY: Float = bodyH * LanghuanShelfGeometry.seatRatio + 12f * density

    /** 行框总高度：静止站位 + 抽出上浮的余量 + 底部留白。 */
    val rowHeight: Float = seatY + volumeH + LanghuanShelfGeometry.rowPadding * density

    /** 封面面板里的图片尺寸（面板上下各留一行档案位）。 */
    val coverImageW: Float = coverW - 20f * density
    val coverImageH: Float = coverImageW * 166f / 118f

    /** 行内弧线的纵向像素量（弧线坡度按 dp 设计）。 */
    fun railY(distance: Float): Float =
        LanghuanShelfGeometry.railY(distance) * density

    /** 行首：让完全抽出的那本书正好落在视口正中。 */
    val rowStart: Float =
        viewport / 2f - footprint / 2f +
            LanghuanShelfGeometry.pull(coverW, 1f) * LanghuanShelfGeometry.depthX
}
