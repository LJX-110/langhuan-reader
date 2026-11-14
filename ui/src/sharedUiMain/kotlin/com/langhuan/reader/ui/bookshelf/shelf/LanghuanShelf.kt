package com.langhuan.reader.ui.bookshelf.shelf

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.langhuan.reader.data.AppDbProviders
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.help.image.ImageBitmapLoader
import com.langhuan.reader.ui.compose.platform.platformTextStyleNoFontPadding
import com.langhuan.reader.ui.compose.platform.rememberString
import com.langhuan.reader.ui.compose.theme.AppColors
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.LanghuanType
import com.langhuan.reader.ui.compose.theme.LocalEInk
import com.langhuan.reader.uimodel.BookItemUi
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.roundToInt
import kotlin.math.sign

// 松手落位：先按摩擦惯性滑行，再用有限三次曲线收到整数格位（无回弹、无过冲）。
// dragRate 决定甩动距离，omega 决定惯性交接速度；两者与手感参考实现保持一致。
private const val SHELF_DRAG_RATE = 4.4f
private const val SHELF_OMEGA = 12f
private const val SHELF_MIN_FLING = 50f
private const val SHELF_HANDOFF_SPEED_FACTOR = 4f

/** 点按居中：参考实现的 620ms 轻微过冲曲线，落在格位上有「吸附」的手感。 */
private const val SHELF_CENTRE_MS = 620

/**
 * 书架外部控制入口：顶栏 tab 双击时回到第一本（对照原版 gotoTop）。
 *
 * 3D 书架没有 LazyList 的滚动状态，滚顶只能由书架自己补间，故用一个自增信号驱动；
 * [offset] 存滚动像素量，pager 回收分组页后仍能回到原来的书。
 */
class LanghuanShelfState {
    internal var goToTopTick by mutableIntStateOf(0)
        private set
    internal var offset by mutableFloatStateOf(0f)
    internal var placed: Boolean = false

    fun gotoTop() {
        goToTopTick++
    }
}

/**
 * 琅嬛阁 3D 书架：一排实体书 + 景深，滚动位置是唯一时钟。
 *
 * 中心那本从行里「抽」出来（cos² 抽出波，左右各到 ±1.48 格），邻书退回书脊，
 * 整排沿行内弧线轻微起伏；松手后落回整数格位。首尾不循环。
 *
 * 绘制全部在一个 Canvas 里完成：书脊 / 封面 / 顶面三块平面共用同一组物理顶点，
 * 封面是沿深度向量 (0.66, -0.30) 斜投影的平行四边形，不是直立矩形。
 *
 * @param books 书架书目（按传入顺序排列）
 * @param coverBook 封面对实体回查: 封面解密 / cbz 取图要完整 [Book], 由页面边界按
 *   [BookItemUi.bookUrl] 回查后注入; 返回 null 时按 [BookItemUi] 自带封面地址加载
 * @param initialBookUrl 首次落点：通常传最近阅读的那本
 * @param state 外部控制入口（tab 双击滚顶）
 * @param refreshEnabled 是否允许下拉刷新
 * @param refreshing 更新目录请求是否在进行中
 * @param onRefresh 下拉过阈值后触发
 * @param onOpen 点按居中那本打开阅读
 * @param onLongPress 长按打开书籍操作菜单
 */
@Composable
fun LanghuanShelf(
    books: List<BookItemUi>,
    modifier: Modifier = Modifier,
    coverBook: (BookItemUi) -> Book? = { null },
    initialBookUrl: String? = null,
    state: LanghuanShelfState = remember { LanghuanShelfState() },
    refreshEnabled: Boolean = false,
    refreshing: Boolean = false,
    onRefresh: () -> Unit = {},
    onOpen: (BookItemUi) -> Unit,
    onLongPress: (BookItemUi) -> Unit,
    emptyContent: (@Composable () -> Unit)? = null,
) {
    val colors = AppTheme.colors
    val unknownAuthor = rememberString("unknown_author")
    if (books.isEmpty()) {
        Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            if (emptyContent != null) {
                emptyContent()
            } else {
                Text(
                    text = rememberString("bookshelf_empty"),
                    color = colors.summaryText,
                    fontSize = 14.sp,
                )
            }
        }
        return
    }

    BoxWithConstraints(modifier.fillMaxSize()) {
        val density = LocalDensity.current
        val viewportPx = with(density) { maxWidth.toPx() }
        val heightPx = with(density) { maxHeight.toPx() }
        val metrics = remember(viewportPx, density.density) {
            LanghuanShelfMetrics(viewportPx, density.density)
        }
        val metaHeightPx = with(density) { 76.dp.toPx() }
        // 行框在剩余空间里居中，书名区固定在底部
        val rowTopPx = ((heightPx - metaHeightPx - metrics.rowHeight) / 2f).coerceAtLeast(0f)
        val rowHeightDp = with(density) { metrics.rowHeight.toDp() }

        val initialIndex = remember(books, initialBookUrl) {
            books.indexOfFirst { it.bookUrl == initialBookUrl }.takeIf { it >= 0 } ?: 0
        }
        val pitch = metrics.pitch
        val maxOffset = ((books.size - 1) * pitch).coerceAtLeast(0f)
        // 滚动位置（px）：拖动直接改它，落位用动画补间。
        // 初始值取自分组状态，pager 回收该页后再回来仍在原位。
        var offset by remember {
            mutableFloatStateOf(
                (if (state.placed) state.offset else initialIndex * pitch)
                    .coerceIn(0f, maxOffset)
            )
        }
        // 把滚动位置写回分组状态，供 pager 回收后再进入时恢复
        SideEffect {
            state.offset = offset
            state.placed = true
        }
        LaunchedEffect(maxOffset) { if (offset > maxOffset) offset = maxOffset }
        var animJob by remember { mutableStateOf<Job?>(null) }
        val scope = rememberCoroutineScope()

        // 入场：整排书沿深度轴滑入（720ms，逐本错开），E-Ink 下直接落位。
        val eInk = LocalEInk.current
        val entrance = remember { Animatable(if (eInk) 1f else 0f) }
        LaunchedEffect(Unit) {
            if (!eInk) entrance.animateTo(1f, tween(720, easing = LinearEasing))
        }

        // 下拉刷新：3D 书架没有纵向滚动容器，pullRefresh 收不到嵌套滚动事件，
        // 这里直接吃纵向拖动，位移量兼作指示器进度。
        val pullTrigger = with(density) { 56.dp.toPx() }
        val pullLimit = with(density) { 96.dp.toPx() }
        var pull by remember { mutableFloatStateOf(0f) }

        fun launchSettle(block: suspend () -> Unit) {
            animJob?.cancel()
            animJob = scope.launch { block() }
        }

        /** 点按 / 双击滚顶：按参考曲线补间到目标格位 */
        fun settleTo(slot: Int) {
            val target = (slot.coerceIn(0, books.lastIndex) * pitch).coerceIn(0f, maxOffset)
            launchSettle {
                animate(
                    offset,
                    target,
                    animationSpec = tween(
                        SHELF_CENTRE_MS,
                        easing = androidx.compose.animation.core.CubicBezierEasing(.2f, 1.06f, .35f, 1f),
                    ),
                ) { value, _ -> offset = value }
            }
        }

        /**
         * 松手落位：[releaseVelocity] 是 offset 方向的速度（px/s）。
         *
         * 先按指数摩擦滑行（保留松手瞬间的速度），在速度降到交接阈值后交给有限三次曲线，
         * 曲线终点速度与加速度都为 0，因此不会在格位上回弹或过冲。
         * 轻拖（未达到最小甩动速度）直接补间到最近格位。
         */
        suspend fun settleWithVelocity(releaseVelocity: Float) {
            val position = offset
            if (pitch <= 0f) return
            val speed = abs(releaseVelocity)
            val directional = speed >= SHELF_MIN_FLING
            val release = if (directional) releaseVelocity else 0f

            var target = ((position + release / SHELF_DRAG_RATE) / pitch).roundToInt() * pitch
            // 真正的甩动要落在前方而不是滑过头再倒回，给惯性留足单调减速的跑道
            if (directional && (target - position) * release.sign < speed / SHELF_OMEGA) {
                val runway = position + release / SHELF_OMEGA
                target = (if (release > 0f) ceil(runway / pitch) else floor(runway / pitch)) * pitch
            }
            target = target.coerceIn(0f, maxOffset)

            if (!directional) {
                animate(position, target, animationSpec = tween(320, easing = FastOutSlowInEasing)) { value, _ ->
                    offset = value
                }
                return
            }

            val handoffSpeed = pitch * SHELF_HANDOFF_SPEED_FACTOR
            val coastDuration = if (speed > handoffSpeed) {
                ln(speed / handoffSpeed) / SHELF_DRAG_RATE
            } else {
                0f
            }
            val expFactor = exp(-SHELF_DRAG_RATE * coastDuration)
            val handoffPosition = position + release / SHELF_DRAG_RATE * (1f - expFactor)
            val handoffVelocity = release * expFactor
            val landingDuration = if (abs(handoffVelocity) > 1f) {
                3f * (target - handoffPosition) / handoffVelocity
            } else {
                0f
            }
            if (landingDuration <= 0f) {
                offset = target
                return
            }

            val startAt = withFrameNanos { it }
            while (true) {
                val now = withFrameNanos { it }
                val t = (now - startAt) / 1_000_000_000f
                offset = if (t < coastDuration) {
                    position + release / SHELF_DRAG_RATE * (1f - exp(-SHELF_DRAG_RATE * t))
                } else {
                    val remaining = (1f - (t - coastDuration) / landingDuration).coerceIn(0f, 1f)
                    target - (target - handoffPosition) * remaining * remaining * remaining
                }
                if (t >= coastDuration + landingDuration) break
            }
            offset = target
        }

        // tab 双击滚顶：回到第一本（书架没有列表滚动状态，滚顶只能落到格位 0）
        LaunchedEffect(state.goToTopTick) {
            if (state.goToTopTick > 0) settleTo(0)
        }

        val centerIndex by remember(pitch, books) {
            derivedStateOf {
                (offset / pitch).roundToInt().coerceIn(0, books.lastIndex)
            }
        }

        // 封面位图：只加载中心与左右邻，离开窗口立即释放
        val loader = remember { ImageBitmapLoader() }
        val covers = remember { mutableStateMapOf<String, ImageBitmap?>() }
        LaunchedEffect(centerIndex, books) {
            covers.keys.retainAll(
                books.subList(
                    (centerIndex - 2).coerceAtLeast(0),
                    (centerIndex + 3).coerceAtMost(books.size),
                ).mapTo(mutableSetOf()) { it.bookUrl }
            )
            for (i in (centerIndex - 1)..(centerIndex + 1)) {
                val book = books.getOrNull(i) ?: continue
                if (covers.containsKey(book.bookUrl)) continue
                // 实体只用于封面解密 / cbz 取图 / 自定义封面相对路径解析, 缺失时退回 Ui 封面地址
                val entity = coverBook(book)
                val url = entity?.getDisplayCover() ?: book.customCoverUrl ?: book.coverUrl
                covers[book.bookUrl] = if (url.isNullOrBlank()) {
                    null
                } else {
                    // 书源决定防盗链 header / cookie / 封面解密规则，缺了它封面会一直只有占位首字
                    val source = book.origin
                        .takeIf { it.isNotBlank() }
                        ?.let { origin ->
                            runCatching {
                                AppDbProviders.get().bookSourceDao.getBookSource(origin)
                            }.getOrNull()
                        }
                    runCatching {
                        loader.loadBitmap(
                            url = url,
                            book = entity,
                            bookSource = source,
                            isCover = true,
                            widthPx = metrics.coverImageW.roundToInt(),
                            heightPx = metrics.coverImageH.roundToInt(),
                        )
                    }.getOrNull()
                }
            }
        }

        // 每本最多十余次排版（编号 / 首字 / 竖排书名逐字），默认缓存 8 条不够，
        // 放大到 128 条让拖动时命中缓存而不是逐帧重排。
        val textMeasurer = rememberTextMeasurer(cacheSize = 128)

        // 单一手势入口：先判定主轴，再在「横拖书架 / 纵向下拉刷新 / 让给分组页签」之间仲裁。
        // 处在首尾且继续向外拖时不消费事件，交还给外层 HorizontalPager 切换分组。
        Box(
            Modifier
                .fillMaxSize()
                .pointerInput(books, pitch, maxOffset, refreshEnabled, refreshing) {
                    val touchSlop = viewConfiguration.touchSlop
                    awaitEachGesture {
                        val down = awaitFirstDown(requireUnconsumed = false)
                        val tracker = VelocityTracker().apply {
                            addPosition(down.uptimeMillis, down.position)
                        }
                        var lastPosition = down.position
                        var totalX = 0f
                        var totalY = 0f
                        var mode = 0 // 0 未定 / 1 横拖书架 / 2 下拉刷新
                        while (true) {
                            val event = awaitPointerEvent()
                            val change = event.changes.firstOrNull { it.id == down.id } ?: break
                            if (!change.pressed) break
                            val dx = change.position.x - lastPosition.x
                            val dy = change.position.y - lastPosition.y
                            lastPosition = change.position
                            tracker.addPosition(change.uptimeMillis, change.position)

                            if (mode == 0) {
                                totalX += dx
                                totalY += dy
                                if (abs(totalX) > touchSlop || abs(totalY) > touchSlop) {
                                    if (abs(totalX) >= abs(totalY)) {
                                        val atStart = offset <= 0.5f && totalX > 0f
                                        val atEnd = offset >= maxOffset - 0.5f && totalX < 0f
                                        if (atStart || atEnd) return@awaitEachGesture
                                        mode = 1
                                    } else {
                                        if (!refreshEnabled || offset > 1f || totalY < 0f) {
                                            return@awaitEachGesture
                                        }
                                        mode = 2
                                    }
                                    animJob?.cancel()
                                }
                            }
                            when (mode) {
                                1 -> {
                                    offset = (offset - dx).coerceIn(0f, maxOffset)
                                    change.consume()
                                }
                                2 -> {
                                    pull = (pull + dy).coerceIn(0f, pullLimit)
                                    change.consume()
                                }
                            }
                        }
                        when (mode) {
                            1 -> launchSettle {
                                settleWithVelocity(-tracker.calculateVelocity().x)
                            }
                            2 -> {
                                val shouldRefresh =
                                    refreshEnabled && !refreshing && pull >= pullTrigger
                                scope.launch {
                                    animate(
                                        pull, 0f,
                                        animationSpec = tween(220, easing = FastOutSlowInEasing),
                                    ) { value, _ -> pull = value }
                                }
                                if (shouldRefresh) onRefresh()
                            }
                        }
                    }
                }
        ) {
            Column(
                Modifier
                    .fillMaxSize()
                    .offset { IntOffset(0, pull.roundToInt()) }
            ) {
                Spacer(Modifier.height(with(density) { rowTopPx.toDp() }))
                Canvas(
                    Modifier
                        .fillMaxWidth()
                        .height(rowHeightDp)
                        .pointerInput(books, pitch, metrics) {
                            detectTapGestures(
                                onTap = { position ->
                                    val index = shelfIndexAt(
                                        position = position,
                                        count = books.size,
                                        focus = offset / pitch,
                                        metrics = metrics,
                                    ) ?: return@detectTapGestures
                                    // 点已居中的那本才打开，点别的先把它转到中心（同参考行为）
                                    val settled = abs(offset / pitch - index) < .03f &&
                                        animJob?.isActive != true
                                    if (settled) onOpen(books[index]) else settleTo(index)
                                },
                                onLongPress = { position ->
                                    val index = shelfIndexAt(
                                        position = position,
                                        count = books.size,
                                        focus = offset / pitch,
                                        metrics = metrics,
                                    ) ?: return@detectTapGestures
                                    onLongPress(books[index])
                                },
                            )
                        }
                ) {
                    drawShelfRow(
                        books = books,
                        offset = offset,
                        metrics = metrics,
                        colors = colors,
                        covers = covers,
                        textMeasurer = textMeasurer,
                        entrance = entrance.value,
                    )
                }
                ShelfMeta(
                    book = books[centerIndex],
                    index = centerIndex,
                    total = books.size,
                    unknownAuthor = unknownAuthor,
                    onPrev = { if (centerIndex > 0) settleTo(centerIndex - 1) },
                    onNext = { if (centerIndex < books.lastIndex) settleTo(centerIndex + 1) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(with(density) { metaHeightPx.toDp() })
                        .padding(start = 16.dp, end = 16.dp, top = 6.dp),
                )
            }
            if (pull > 0f || refreshing) {
                val pullHint = when {
                    refreshEnabled && (pull >= pullTrigger) -> rememberString("shelf_release_refresh")
                    refreshing -> rememberString("shelf_refreshing")
                    else -> rememberString("shelf_pull_refresh")
                }
                Text(
                    text = pullHint,
                    color = colors.summaryText,
                    fontSize = 11.sp,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .offset { IntOffset(0, (pull * .38f).roundToInt()) }
                        .padding(top = 10.dp),
                )
            }
        }
    }
}

/**
 * 一本书在场景里的落点与三块平面。
 *
 * 三块平面共用 [ox]/[oy] 这一组物理顶点：
 * - 书脊：x 轴轻微切变（[LanghuanShelfGeometry.spineShear]）后直立在行上
 * - 封面：从书脊顶边沿深度向量斜投影展开的平行四边形
 * - 顶面：连接书脊顶边与封面顶边的四边形（纸厚）
 */
private class ShelfSlot(
    val index: Int,
    val volumeX: Float,
    val volumeY: Float,
    val ox: Float,
    val oy: Float,
    val spineW: Float,
    val bodyH: Float,
    val coverW: Float,
    val spinePath: Path,
    val coverPath: Path,
    val topPath: Path,
) {
    /** 命中测试：书脊与封面都是仿射平行四边形，反解 (u, v) 判断是否落在面上。 */
    fun hitTest(point: Offset): Boolean {
        // 书脊：p = o + u*(1, shear) + v*(0, 1)
        val spineU = point.x - ox
        if (spineU in 0f..spineW) {
            val v = point.y - oy - spineU * LanghuanShelfGeometry.spineShear
            if (v in 0f..bodyH) return true
        }
        // 封面：p = o + spine*(1, shear) + u*(depthX, depthY) + v*(0, 1)
        val coverU = (point.x - ox - spineW) / LanghuanShelfGeometry.depthX
        if (coverU in 0f..coverW) {
            val v = point.y - oy - spineW * LanghuanShelfGeometry.spineShear -
                coverU * LanghuanShelfGeometry.depthY
            if (v in 0f..bodyH) return true
        }
        return false
    }
}

private fun shelfSlot(
    index: Int,
    focus: Float,
    metrics: LanghuanShelfMetrics,
    viewport: Float,
    entrance: Float,
): ShelfSlot {
    val distance = index - focus
    val weight = LanghuanShelfGeometry.wave(distance) * entranceCrest(entrance)
    val assembly = assemblyOffset(distance, viewport, metrics.pitch, metrics.density, entrance)
    val volumeX = metrics.rowStart + distance * metrics.pitch + assembly.x
    val volumeY = metrics.railY(distance) + assembly.y
    val ox = volumeX + metrics.extractionX(weight)
    val oy = volumeY + metrics.extractionY(weight)

    val spine = metrics.spineW
    val body = metrics.bodyH
    val shear = LanghuanShelfGeometry.spineShear
    val rightX = ox + spine
    val rightY = oy + spine * shear
    val depthX = metrics.coverW * LanghuanShelfGeometry.depthX
    val depthY = metrics.coverW * LanghuanShelfGeometry.depthY

    val spinePath = Path().apply {
        moveTo(ox, oy)
        lineTo(rightX, rightY)
        lineTo(rightX, rightY + body)
        lineTo(ox, oy + body)
        close()
    }
    val coverPath = Path().apply {
        moveTo(rightX, rightY)
        lineTo(rightX + depthX, rightY + depthY)
        lineTo(rightX + depthX, rightY + depthY + body)
        lineTo(rightX, rightY + body)
        close()
    }
    val topPath = Path().apply {
        moveTo(ox, oy)
        lineTo(rightX, rightY)
        lineTo(rightX + depthX, rightY + depthY)
        lineTo(ox + depthX, oy + depthY)
        close()
    }
    return ShelfSlot(
        index = index,
        volumeX = volumeX,
        volumeY = volumeY,
        ox = ox,
        oy = oy,
        spineW = spine,
        bodyH = body,
        coverW = metrics.coverW,
        spinePath = spinePath,
        coverPath = coverPath,
        topPath = topPath,
    )
}

/** 入场权重：0.38 之前不动，之后按 easeOutCubic 升到 1。 */
private fun entranceCrest(entrance: Float): Float {
    if (entrance >= 1f) return 1f
    return easeOutCubic(((entrance - .38f) / .62f).coerceIn(0f, 1f))
}

/** 入场位移：逐本错开，沿深度轴从 56dp 外滑到原位。 */
private fun assemblyOffset(
    distance: Float,
    viewport: Float,
    pitch: Float,
    density: Float,
    entrance: Float,
): Offset {
    if (entrance >= 1f) return Offset.Zero
    val order = (distance + viewport / pitch / 2f + 2f).coerceIn(0f, 16f)
    val start = order * .018f
    val progress = easeOutCubic(((entrance - start) / .52f).coerceIn(0f, 1f))
    val travel = 56f * density * (1f - progress)
    return Offset(LanghuanShelfGeometry.depthX * travel, LanghuanShelfGeometry.depthY * travel)
}

private fun easeOutCubic(t: Float): Float {
    val inv = 1f - t
    return 1f - inv * inv * inv
}

/** 命中测试：按实际三块平面判断，未命中再按格位步长就近换算。 */
private fun shelfIndexAt(
    position: Offset,
    count: Int,
    focus: Float,
    metrics: LanghuanShelfMetrics,
): Int? {
    val reach = visibleReach(metrics) + 1f
    val first = floor(focus - reach).toInt().coerceIn(0, count - 1)
    val last = ceil(focus + reach).toInt().coerceIn(first, count - 1)
    // 右邻画在左邻之上，命中也要从右往左找
    for (index in last downTo first) {
        val slot = shelfSlot(index, focus, metrics, metrics.viewport, 1f)
        if (slot.hitTest(position)) return index
    }
    val guess = focus + (position.x - metrics.rowStart) / metrics.pitch
    return guess.roundToInt().coerceIn(0, count - 1)
}

private fun visibleReach(metrics: LanghuanShelfMetrics): Float =
    metrics.viewport / 2f / metrics.pitch +
        (metrics.footprint + metrics.pullDistance) / metrics.pitch

/** 整排书：先铺地面投影，再按格位顺序（左 → 右）画书。 */
private fun DrawScope.drawShelfRow(
    books: List<BookItemUi>,
    offset: Float,
    metrics: LanghuanShelfMetrics,
    colors: AppColors,
    covers: Map<String, ImageBitmap?>,
    textMeasurer: TextMeasurer,
    entrance: Float,
) {
    val pitch = metrics.pitch
    if (pitch <= 0f) return
    val focus = offset / pitch
    val reach = visibleReach(metrics)
    val first = floor(focus - reach).toInt().coerceIn(0, books.lastIndex)
    val last = ceil(focus + reach).toInt().coerceIn(first, books.lastIndex)
    if (last < first) return

    val slots = (first..last).map { shelfSlot(it, focus, metrics, size.width, entrance) }
    val styles = shelfTextStyles(colors)

    clipRect(0f, 0f, size.width, size.height) {
        for (slot in slots) drawFloorShadow(slot, metrics, colors)
        // 平行排布的书按格位顺序绘制：右邻书的封面压住左邻的纵深，与真实遮挡一致。
        // 不按「离中心远近」排序，拖动时不会出现层序跳变。
        for (slot in slots) {
            drawVolume(
                book = books[slot.index],
                slot = slot,
                metrics = metrics,
                colors = colors,
                styles = styles,
                cover = covers[books[slot.index].bookUrl],
                textMeasurer = textMeasurer,
            )
        }
    }
}

/** 地面投影：书脊底边沿深度向量铺开的一条窄带，从右上到左下渐隐。 */
private fun DrawScope.drawFloorShadow(
    slot: ShelfSlot,
    metrics: LanghuanShelfMetrics,
    colors: AppColors,
) {
    val d = metrics.density
    val origin = Offset(slot.volumeX, slot.volumeY + metrics.baseY + metrics.bodyH)
    val depth = Offset(
        metrics.coverW * LanghuanShelfGeometry.depthX,
        metrics.coverW * LanghuanShelfGeometry.depthY,
    )
    val path = Path().apply {
        moveTo(origin.x, origin.y)
        lineTo(origin.x + metrics.spineW, origin.y + 1.4f * d)
        lineTo(origin.x + metrics.spineW + depth.x, origin.y + 1.4f * d + depth.y)
        lineTo(origin.x + depth.x, origin.y + depth.y)
        lineTo(origin.x + depth.x - 10f * d, origin.y + depth.y + 10f * d)
        lineTo(origin.x - 10f * d, origin.y + 10f * d)
        close()
    }
    val bounds = path.getBounds()
    drawPath(
        path = path,
        brush = Brush.linearGradient(
            colors = listOf(
                colors.shelfFloor.copy(alpha = .10f),
                colors.shelfFloor.copy(alpha = 0f),
            ),
            start = Offset(bounds.right, bounds.top),
            end = Offset(bounds.left, bounds.bottom),
        ),
    )
}

/** 一本书：封面 → 顶面 → 书脊（书脊压在封面接缝上，遮住分缝）。 */
private fun DrawScope.drawVolume(
    book: BookItemUi,
    slot: ShelfSlot,
    metrics: LanghuanShelfMetrics,
    colors: AppColors,
    styles: ShelfTextStyles,
    cover: ImageBitmap?,
    textMeasurer: TextMeasurer,
) {
    val d = metrics.density
    val spine = metrics.spineW
    val body = metrics.bodyH
    val shear = LanghuanShelfGeometry.spineShear
    val number = slot.index + 1

    // 封面：x 轴沿深度向量斜投影，y 轴保持竖直 —— 与参考的 coverTransform 一致
    val coverMatrix = Matrix().apply {
        this[0, 0] = LanghuanShelfGeometry.depthX
        this[1, 0] = LanghuanShelfGeometry.depthY
        this[0, 3] = slot.ox + spine
        this[1, 3] = slot.oy + spine * shear
    }
    withTransform({ transform(coverMatrix) }) {
        clipRect(0f, 0f, metrics.coverW, body) {
            drawRect(colors.shelfCover, Offset.Zero, Size(metrics.coverW, body))
            drawCoverContent(book, number, metrics, colors, styles, cover, textMeasurer)
            drawRect(
                color = colors.line,
                topLeft = Offset.Zero,
                size = Size(metrics.coverW, body),
                style = Stroke(.7f * d),
            )
        }
    }

    // 顶面：书脊顶边与封面顶边之间的纸厚
    val topBounds = slot.topPath.getBounds()
    val topMidY = (topBounds.top + topBounds.bottom) / 2f
    drawPath(
        path = slot.topPath,
        brush = Brush.linearGradient(
            colors = listOf(colors.shelfTop, colors.shelfSpine),
            start = Offset(topBounds.left, topMidY),
            end = Offset(topBounds.right, topMidY),
        ),
    )
    drawPath(
        path = slot.topPath,
        color = colors.shelfEdge.copy(alpha = .24f),
        style = Stroke(.4f * d),
    )

    // 书脊：x 轴轻微切变，直立在标题行上
    val spineMatrix = Matrix().apply {
        this[1, 0] = shear
        this[0, 3] = slot.ox
        this[1, 3] = slot.oy
    }
    withTransform({ transform(spineMatrix) }) {
        clipRect(0f, 0f, spine, body) {
            drawRect(colors.shelfSpine, Offset.Zero, Size(spine, body))
            drawSpineContent(book, number, metrics, colors, styles, textMeasurer)
            drawRect(
                color = colors.line,
                topLeft = Offset.Zero,
                size = Size(spine, body),
                style = Stroke(.7f * d),
            )
        }
    }
}

/** 封面内容：NO.xxx → 封面图 → 文件代号（左对齐，上下各留一行档案位）。 */
private fun DrawScope.drawCoverContent(
    book: BookItemUi,
    number: Int,
    metrics: LanghuanShelfMetrics,
    colors: AppColors,
    styles: ShelfTextStyles,
    cover: ImageBitmap?,
    textMeasurer: TextMeasurer,
) {
    val d = metrics.density
    val left = 10f * d
    val codeLayout = textMeasurer.measure(
        "NO.${number.toString().padStart(3, '0')}",
        styles.code,
    )
    drawText(codeLayout, topLeft = Offset(left, 9f * d))

    val imageTop = 9f * d + codeLayout.size.height + 7f * d
    val imageW = metrics.coverImageW
    val imageH = metrics.coverImageH
    if (cover != null) {
        // 等比裁切填满封面格（BoxFit.cover），不拉伸变形
        val scale = maxOf(imageW / cover.width, imageH / cover.height)
        val srcW = (imageW / scale).roundToInt().coerceIn(1, cover.width)
        val srcH = (imageH / scale).roundToInt().coerceIn(1, cover.height)
        drawImage(
            image = cover,
            srcOffset = IntOffset((cover.width - srcW) / 2, (cover.height - srcH) / 2),
            srcSize = IntSize(srcW, srcH),
            dstOffset = IntOffset(left.roundToInt(), imageTop.roundToInt()),
            dstSize = IntSize(imageW.roundToInt(), imageH.roundToInt()),
            filterQuality = FilterQuality.Medium,
        )
    } else {
        drawRect(colors.paperDeep, Offset(left, imageTop), Size(imageW, imageH))
        val initial = book.name.take(1)
        val layout = textMeasurer.measure(initial, styles.initial)
        drawText(
            layout,
            topLeft = Offset(
                left + (imageW - layout.size.width) / 2f,
                imageTop + (imageH - layout.size.height) / 2f,
            ),
        )
    }

    val fileLayout = textMeasurer.measure(fileCode(book), styles.code)
    drawText(
        fileLayout,
        topLeft = Offset(left, metrics.bodyH - 8f * d - fileLayout.size.height),
    )
}

/** 书脊内容：顶部编号 → 竖排书名（每行一字）→ 底部圆点。 */
private fun DrawScope.drawSpineContent(
    book: BookItemUi,
    number: Int,
    metrics: LanghuanShelfMetrics,
    colors: AppColors,
    styles: ShelfTextStyles,
    textMeasurer: TextMeasurer,
) {
    val d = metrics.density
    val spine = metrics.spineW
    val body = metrics.bodyH

    val codeLayout = textMeasurer.measure(
        number.toString().padStart(2, '0'),
        styles.code,
    )
    val maxW = (spine - 2f * d).coerceAtLeast(1f)
    val fit = if (codeLayout.size.width > maxW) maxW / codeLayout.size.width else 1f
    val codeH = codeLayout.size.height * fit
    if (fit < 1f) {
        withTransform({
            translate((spine - codeLayout.size.width * fit) / 2f, 9f * d)
            scale(fit, fit, pivot = Offset.Zero)
        }) {
            drawText(codeLayout, topLeft = Offset.Zero)
        }
    } else {
        drawText(
            codeLayout,
            topLeft = Offset((spine - codeLayout.size.width) / 2f, 9f * d),
        )
    }

    val glyphs = book.name.take(7).toList().let {
        if (book.name.length > 7) it + '…' else it
    }
    if (glyphs.isNotEmpty()) {
        val layouts = glyphs.map { textMeasurer.measure(it.toString(), styles.title) }
        val lineHeight = layouts.maxOf { it.size.height }.toFloat()
        val top = 9f * d + codeH + 10f * d
        val bottom = body - 21f * d
        val total = lineHeight * layouts.size
        var y = top + ((bottom - top - total) / 2f).coerceAtLeast(0f)
        for (layout in layouts) {
            drawText(
                layout,
                topLeft = Offset(
                    (spine - layout.size.width) / 2f,
                    y + (lineHeight - layout.size.height) / 2f,
                ),
            )
            y += lineHeight
        }
    }

    // 书脊底部的小圆点：整面书脊唯一的辅助色触点
    drawCircle(
        color = colors.companion.copy(alpha = .85f),
        radius = 3f * d,
        center = Offset(spine / 2f, body - 12f * d),
    )
}

private class ShelfTextStyles(
    val code: TextStyle,
    val title: TextStyle,
    val initial: TextStyle,
)

private fun shelfTextStyles(colors: AppColors): ShelfTextStyles = ShelfTextStyles(
    code = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontSize = 9.sp,
        lineHeight = 12.sp,
        letterSpacing = 1.05.sp,
        fontWeight = FontWeight.Medium,
        color = colors.summaryText,
        platformStyle = platformTextStyleNoFontPadding(),
    ),
    title = TextStyle(
        fontSize = 9.sp,
        lineHeight = (9f * 1.08f).sp,
        fontWeight = FontWeight.SemiBold,
        color = colors.primaryText,
        platformStyle = platformTextStyleNoFontPadding(),
    ),
    initial = TextStyle(
        fontSize = 34.sp,
        fontWeight = FontWeight.SemiBold,
        color = colors.summaryText.copy(alpha = .55f),
        platformStyle = platformTextStyleNoFontPadding(),
    ),
)

/** 文件代号：书没有数字主键，用书址哈希取五位，保证同一本书每次一致。 */
private fun fileCode(book: BookItemUi): String {
    val code = (book.bookUrl.hashCode().toLong() and 0xFFFF_FFFFL) % 100_000L
    return "WK-" + code.toString().padStart(5, '0')
}

/** 书名区：当前居中那本的名字、作者与格位计数。 */
@Composable
private fun ShelfMeta(
    book: BookItemUi,
    index: Int,
    total: Int,
    unknownAuthor: String,
    onPrev: () -> Unit,
    onNext: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    // 与参考页一致：书名 17sp 加粗、副标题 12sp、页码等宽小字
    val titleStyle = TextStyle(
        fontFamily = LanghuanType.serif,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        fontWeight = FontWeight.Bold,
        letterSpacing = (-0.2).sp,
    )
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(
                text = book.name,
                style = titleStyle,
                color = colors.accent,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(3.dp))
            val chapter = book.durChapterTitle
            val meta = if (chapter.isNullOrBlank()) {
                book.author.ifBlank { unknownAuthor }
            } else {
                "${book.author.ifBlank { unknownAuthor }} · $chapter"
            }
            Text(
                text = meta,
                color = colors.summaryText,
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Spacer(Modifier.width(10.dp))
        if (total > 1) {
            ShelfPageStepper(
                index = index,
                total = total,
                onPrev = onPrev,
                onNext = onNext,
            )
        }
    }
}

/** 翻页指示：`< 03 / 08 >`，两侧箭头可点，落位到相邻书。 */
@Composable
private fun ShelfPageStepper(
    index: Int,
    total: Int,
    onPrev: () -> Unit,
    onNext: () -> Unit,
) {
    val colors = AppTheme.colors
    Row(verticalAlignment = Alignment.CenterVertically) {
        ShelfStepperArrow("<", enabled = index > 0, onClick = onPrev, color = colors.summaryText)
        Text(
            text = "${(index + 1).toString().padStart(2, '0')} / " +
                total.toString().padStart(2, '0'),
            color = colors.summaryText,
            fontSize = 10.sp,
            letterSpacing = 1.sp,
            modifier = Modifier.padding(horizontal = 2.dp),
        )
        ShelfStepperArrow("<", rotation = 180f, enabled = index < total - 1, onClick = onNext, color = colors.summaryText)
    }
}

@Composable
private fun ShelfStepperArrow(
    glyph: String,
    enabled: Boolean,
    color: Color,
    onClick: () -> Unit,
    rotation: Float = 0f,
) {
    Box(
        Modifier
            .size(28.dp)
            .clip(RoundedCornerShape(14.dp))
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = glyph,
            color = color.copy(alpha = if (enabled) 1f else .35f),
            fontSize = 14.sp,
            modifier = Modifier.rotate(rotation),
        )
    }
}
