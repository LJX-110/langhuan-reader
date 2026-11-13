package com.langhuan.reader.ui.bookshelf.shelf

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.layout.width
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
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
import com.langhuan.reader.ui.compose.theme.AppColors
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.LanghuanType
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
 * 琅嬛阁 3D 书架：一排书脊 + 景深，滚动位置是唯一时钟。
 *
 * 中心那本从行里「抽」出来（cos² 抽出波，左右各到 ±1.48 格），邻书退回书脊，
 * 整排沿行内弧线轻微下沉；松手后落回整数格位。首尾不循环。
 *
 * 绘制全部在一个 Canvas 里完成：整排书的书脊 / 封面 / 顶面共享同一批顶点，
 * 拖动与惯性只改一个偏移量，不触发子组件重组。
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
    if (books.isEmpty()) {
        Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            if (emptyContent != null) {
                emptyContent()
            } else {
                Text(
                    text = "书架还是空的",
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

        // 下拉刷新：3D 书架没有纵向滚动容器，pullRefresh 收不到嵌套滚动事件，
        // 这里直接吃纵向拖动，位移量兼作指示器进度。
        val pullTrigger = with(density) { 56.dp.toPx() }
        val pullLimit = with(density) { 96.dp.toPx() }
        var pull by remember { mutableFloatStateOf(0f) }

        fun launchSettle(block: suspend () -> Unit) {
            animJob?.cancel()
            animJob = scope.launch { block() }
        }

        /** 点按 / 双击滚顶：直接补间到目标格位 */
        fun settleTo(slot: Int) {
            val target = (slot.coerceIn(0, books.lastIndex) * pitch).coerceIn(0f, maxOffset)
            launchSettle {
                animate(offset, target, animationSpec = tween(320, easing = FastOutSlowInEasing)) { value, _ ->
                    offset = value
                }
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

        /**
         * 命中哪一格：先看被抽出的那本（它画在中心左边），否则按格位步长就近换算。
         *
         * 书脊间距是 [LanghuanShelfMetrics.pitch]，而一本书的可见宽度（书脊 + 封面投影）
         * 远大于间距，直接按「区间包含」判定会让相邻书的命中区大量重叠，故用格位中心就近判定。
         */
        fun slotAt(x: Float): Int {
            val focus = (offset / pitch).coerceIn(0f, books.lastIndex.toFloat())
            val center = focus.roundToInt().coerceIn(0, books.lastIndex)
            val extraction = LanghuanShelfGeometry.extractionX(
                metrics.coverW,
                LanghuanShelfGeometry.wave(center - focus),
            )
            val centerLeft = metrics.rowStart + center * pitch - offset + extraction
            if (x >= centerLeft && x <= centerLeft + metrics.footprint) return center
            return ((offset + x - metrics.rowStart - metrics.spineW / 2f) / pitch).roundToInt()
                .coerceIn(0, books.lastIndex)
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

        // 每本最多 12 次排版（编号/首字/作者/竖排书名逐字），默认缓存 8 条不够，
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
                        .pointerInput(books, pitch) {
                            detectTapGestures(
                                onTap = { position ->
                                    books.getOrNull(slotAt(position.x))?.let(onOpen)
                                },
                                onLongPress = { position ->
                                    books.getOrNull(slotAt(position.x))?.let(onLongPress)
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
                    )
                }
                ShelfMeta(
                    book = books[centerIndex],
                    index = centerIndex,
                    total = books.size,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(with(density) { metaHeightPx.toDp() })
                        .padding(start = 16.dp, end = 16.dp, top = 6.dp),
                )
            }
            if (pull > 0f || refreshing) {
                Text(
                    text = when {
                        refreshEnabled && (pull >= pullTrigger) -> "松手刷新目录"
                        refreshing -> "正在更新目录…"
                        else -> "下拉刷新目录"
                    },
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

/** 整排书：先铺地面投影，再按格位顺序（左 → 右）画书。 */
private fun DrawScope.drawShelfRow(
    books: List<BookItemUi>,
    offset: Float,
    metrics: LanghuanShelfMetrics,
    colors: AppColors,
    covers: Map<String, ImageBitmap?>,
    textMeasurer: TextMeasurer,
) {
    val pitch = metrics.pitch
    if (pitch <= 0f) return
    val focus = offset / pitch
    val margin = metrics.footprint + metrics.coverW
    val first = floor((offset - margin) / pitch).toInt().coerceAtLeast(0)
    val last = ceil((offset + size.width + margin) / pitch).toInt()
        .coerceAtMost(books.lastIndex)

    // 投影先铺满一层：任何一本书的阴影都落在所有书下面
    for (slot in first..last) {
        drawFloorShadow(slot, focus, metrics, colors)
    }
    // 平行排布的书按格位顺序绘制：右邻书的封面压住左邻书的纵深，与真实遮挡一致。
    // 不再按「离中心远近」排序，拖动时不会出现层序跳变。
    for (slot in first..last) {
        drawBook(
            book = books[slot],
            slot = slot,
            focus = focus,
            metrics = metrics,
            colors = colors,
            cover = covers[books[slot].bookUrl],
            textMeasurer = textMeasurer,
        )
    }
}

/**
 * 地面投影：书脊底边沿深度向量铺开的一块梯形，右下角再拖出两道小斜边。
 *
 * 用从右上到左下的渐隐填充，书才像站在台面上而不是浮在纸面上。
 * 与书体共用 [slotBase] 的顶点，拖动/抽出时阴影跟着走。
 */
private fun DrawScope.drawFloorShadow(
    slot: Int,
    focus: Float,
    metrics: LanghuanShelfMetrics,
    colors: AppColors,
) {
    val (baseX, baseY, _) = slotBase(slot, focus, metrics)
    val d = metrics.density
    val origin = Offset(baseX, baseY + metrics.topInset + metrics.bodyH)
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
    val ink = colors.primaryText
    drawPath(
        path = path,
        brush = Brush.linearGradient(
            colors = listOf(ink.copy(alpha = .10f), ink.copy(alpha = 0f)),
            start = Offset(bounds.right, bounds.top),
            end = Offset(bounds.left, bounds.bottom),
        ),
    )
}

private fun slotBase(
    slot: Int,
    focus: Float,
    metrics: LanghuanShelfMetrics,
): Triple<Float, Float, Float> {
    val distance = slot - focus
    val weight = LanghuanShelfGeometry.wave(distance)
    val x = metrics.rowStart + slot * metrics.pitch - focus * metrics.pitch
    val restY = metrics.seatY + metrics.railY(distance)
    val extractionY = LanghuanShelfGeometry.extractionY(metrics.coverW, metrics.bodyH, weight)
    val extractionX = LanghuanShelfGeometry.extractionX(metrics.coverW, weight)
    return Triple(x + extractionX, restY + extractionY, weight)
}

/** 一本书：这里画顶面、封面、书脊。 */
private fun DrawScope.drawBook(
    book: BookItemUi,
    slot: Int,
    focus: Float,
    metrics: LanghuanShelfMetrics,
    colors: AppColors,
    cover: ImageBitmap?,
    textMeasurer: TextMeasurer,
) {
    val (baseX, baseY, _) = slotBase(slot, focus, metrics)
    val d = metrics.density
    val shear = LanghuanShelfGeometry.spineShear
    val spineTop = Offset(baseX, baseY + metrics.topInset)
    val spineTopRight = Offset(
        baseX + metrics.spineW,
        baseY + metrics.topInset + metrics.spineW * shear,
    )
    val depth = Offset(
        metrics.coverW * LanghuanShelfGeometry.depthX,
        metrics.coverW * LanghuanShelfGeometry.depthY,
    )
    val panelA = spineTopRight

    // 顶面：书脊顶边沿深度向量推出去的一条窄带，不是整张封面。
    // 上一版把顶面画到了封面全宽，看起来像摊开的一张纸，这是「生硬感」的主要来源。
    val topPath = Path().apply {
        moveTo(spineTop.x, spineTop.y)
        lineTo(panelA.x, panelA.y)
        lineTo(panelA.x + depth.x, panelA.y + depth.y)
        lineTo(spineTop.x + depth.x, spineTop.y + depth.y)
        close()
    }
    val topBounds = topPath.getBounds()
    drawPath(
        path = topPath,
        brush = Brush.verticalGradient(
            colors = listOf(
                blend(colors.paper, Color.Black, .10f),
                blend(colors.paper, Color.White, .05f),
            ),
            startY = topBounds.bottom,
            endY = topBounds.top,
        ),
    )
    drawPath(
        path = topPath,
        color = colors.primaryText.copy(alpha = .22f),
        style = Stroke(width = .6f * d),
    )

    // 封面面板：在局部坐标里画，再整体沿深度向量压扁
    // 注意: Compose Matrix 的 values 是列主序, 平移落在 values[12]/[13],
    // 即访问器下标为 [3,0]/[3,1]; 写成 [0,3]/[1,3] 会落进透视项,
    // 整块封面被除到画布原点附近, 表现为「没有封面」+ 一团灰影。
    drawContext.canvas.save()
    drawContext.canvas.concat(
        Matrix().apply {
            this[0, 0] = LanghuanShelfGeometry.depthX
            this[1, 0] = LanghuanShelfGeometry.depthY
            this[3, 0] = panelA.x
            this[3, 1] = panelA.y
        }
    )
    val panelPath = Path().apply {
        moveTo(0f, 0f)
        lineTo(metrics.coverW, 0f)
        lineTo(metrics.coverW, metrics.bodyH)
        lineTo(0f, metrics.bodyH)
        close()
    }
    drawPath(panelPath, colors.paper)
    drawPath(panelPath, colors.line, style = Stroke(width = 1f))

    val coverCode = "NO.${(slot + 1).toString().padStart(3, '0')}"
    val codeStyle = TextStyle(fontSize = 9.sp, fontWeight = FontWeight.Medium, color = colors.summaryText)
    drawText(textMeasurer, coverCode, topLeft = Offset(10f * d, 9f * d), style = codeStyle)

    val imageLeft = 10f * d
    val imageTop = 9f * d + textMeasurer.measure(coverCode, codeStyle).size.height + 7f * d
    if (cover != null) {
        clipRect(imageLeft, imageTop, metrics.coverW - 10f * d, imageTop + metrics.coverImageH) {
            drawImage(
                image = cover,
                srcOffset = IntOffset.Zero,
                srcSize = IntSize(cover.width, cover.height),
                dstOffset = IntOffset(imageLeft.roundToInt(), imageTop.roundToInt()),
                dstSize = IntSize(
                    metrics.coverImageW.roundToInt(),
                    metrics.coverImageH.roundToInt(),
                ),
            )
        }
    } else {
        drawRect(
            color = colors.paperDeep,
            topLeft = Offset(imageLeft, imageTop),
            size = Size(metrics.coverImageW, metrics.coverImageH),
        )
        // 无封面：书名首字落在封面上，避免整格空白
        val initial = book.name.take(1)
        val initialStyle = TextStyle(
            fontSize = 34.sp,
            fontWeight = FontWeight.SemiBold,
            color = colors.summaryText.copy(alpha = .55f),
        )
        val layout = textMeasurer.measure(initial, initialStyle)
        drawText(
            textLayoutResult = layout,
            topLeft = Offset(
                imageLeft + (metrics.coverImageW - layout.size.width) / 2f,
                imageTop + (metrics.coverImageH - layout.size.height) / 2f,
            ),
            color = colors.summaryText.copy(alpha = .55f),
        )
    }

    val author = book.author.ifBlank { "未知作者" }
    val authorStyle = TextStyle(fontSize = 9.sp, color = colors.summaryText)
    drawText(
        textMeasurer,
        author,
        topLeft = Offset(imageLeft, metrics.bodyH - 18f * d),
        style = authorStyle,
        overflow = TextOverflow.Ellipsis,
        maxLines = 1,
        size = Size(metrics.coverImageW, 18f * d),
    )
    drawContext.canvas.restore()

    // 书脊：整排书统一用纸色，不再用主题色铺满。
    // 参考实现里书脊是米白纸面 + 深色竖排书名，主题色只留在书名区等小面积位置；
    // 上一版每本书脊都是一条高饱和色带，远看像一排色卡，这是「生硬」的第二个来源。
    val spinePath = Path().apply {
        moveTo(spineTop.x, spineTop.y)
        lineTo(spineTopRight.x, spineTopRight.y)
        lineTo(spineTopRight.x, spineTopRight.y + metrics.bodyH)
        lineTo(spineTop.x, spineTop.y + metrics.bodyH)
        close()
    }
    val spinePaper = colors.paperDeep
    drawPath(
        path = spinePath,
        brush = Brush.horizontalGradient(
            colors = listOf(
                blend(spinePaper, Color.Black, .06f),
                spinePaper,
                blend(spinePaper, Color.White, .05f),
            ),
            startX = spineTop.x,
            endX = spineTopRight.x,
        ),
    )
    drawPath(
        path = spinePath,
        color = colors.line.copy(alpha = .55f),
        style = Stroke(width = .6f * d),
    )

    val spineInk = colors.primaryText
    val spineCode = (slot + 1).toString().padStart(2, '0')
    val spineCodeStyle = TextStyle(
        fontSize = 8.5.sp,
        fontWeight = FontWeight.Medium,
        color = spineInk.copy(alpha = .62f),
    )
    val spineCodeLayout = textMeasurer.measure(spineCode, spineCodeStyle)
    drawText(
        textLayoutResult = spineCodeLayout,
        topLeft = Offset(
            spineTop.x + (metrics.spineW - spineCodeLayout.size.width) / 2f,
            spineTop.y + metrics.spineW * shear + 8f * d,
        ),
    )

    // 竖排书名：一行一个字，最多七行
    val chars = book.name.take(7).toList().let {
        if (book.name.length > 7) it + '…' else it
    }
    val titleStyle = TextStyle(
        fontSize = 9.sp,
        fontWeight = FontWeight.Medium,
        color = spineInk,
    )
    val charHeight = textMeasurer.measure("书", titleStyle).size.height.toFloat()
    val totalHeight = charHeight * chars.size
    var y = spineTop.y + metrics.bodyH / 2f - totalHeight / 2f
    for (ch in chars) {
        val layout = textMeasurer.measure(ch.toString(), titleStyle)
        drawText(
            textLayoutResult = layout,
            topLeft = Offset(
                spineTop.x + (metrics.spineW - layout.size.width) / 2f,
                y,
            ),
        )
        y += charHeight
    }

    // 书脊底部的小圆点：参考实现用一枚 6dp 圆点收尾，比整块投影安静。
    // 用辅助色而不是灰：这是每本书脊上唯一的主题色触点，面积小，不喧宾夺主
    drawCircle(
        color = colors.companion.copy(alpha = .8f),
        radius = 3f * d,
        center = Offset(
            spineTop.x + metrics.spineW / 2f,
            spineTop.y + metrics.bodyH - 10f * d,
        ),
    )
}

private fun blend(base: Color, overlay: Color, fraction: Float): Color = Color(
    red = base.red + (overlay.red - base.red) * fraction,
    green = base.green + (overlay.green - base.green) * fraction,
    blue = base.blue + (overlay.blue - base.blue) * fraction,
    alpha = base.alpha,
)

/** 书名区：当前居中那本的名字、作者与格位计数。 */
@Composable
private fun ShelfMeta(
    book: BookItemUi,
    index: Int,
    total: Int,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    Row(modifier) {
        Column(Modifier.weight(1f)) {
            Text(
                text = book.name,
                style = LanghuanType.bookTitle,
                color = colors.accent,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(2.dp))
            val chapter = book.durChapterTitle
            val meta = if (chapter.isNullOrBlank()) {
                book.author.ifBlank { "未知作者" }
            } else {
                "${book.author.ifBlank { "未知作者" }} · $chapter"
            }
            Text(
                text = meta,
                color = colors.summaryText,
                fontSize = 11.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Spacer(Modifier.width(10.dp))
        Text(
            text = "${(index + 1).toString().padStart(2, '0')} / " +
                total.toString().padStart(2, '0'),
            color = colors.summaryText,
            fontSize = 10.sp,
            letterSpacing = 1.sp,
        )
    }
}
