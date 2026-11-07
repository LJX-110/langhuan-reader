# 琅嬛阁 · 统一标准（代码与功能）

- 生效：2026-11-03；本文件是「改了很多次之后」的收敛口径，新代码必须按此写，旧代码按批次收敛。
- 两线分界：**外观/动效/交互 → 轻小说文库；阅读/正文/净化/目录/书源内核 → 阅读（Legado）**。阅读页视觉用文库语言承载阅读语义。

## 一、目录结构（现状口径）

| 目录 | 职责 | 规则 |
|---|---|---|
| `lib/app/` | 入口、路由（fluro）、外壳（MainShell） | 只放装配与导航，不放业务 |
| `lib/core/` | 平台桥、存储、网络、数据库、工具、事件 | 无 UI 依赖 |
| `lib/data/` | entities + repositories（sqflite） | 只被上层依赖 |
| `lib/design/` | `motion.dart`（动效词表）、tokens、theme、`components/`（公共组件） | **页面不得再散落时长/颜色/空态自绘** |
| `lib/features/<域>/` | 每域 `页面 + model + service + widgets`；详情 `detail/`、发现 `discover/`、本地 `local/`、我的 `profile/`、阅读器 `reader/`、搜索 `search/`、设置 `settings/`、书架 `shelf/`、书源 `sources/` | 新增页面进对应域；跨域公共 UI 上移 `design/components` |
| `engine/` | 阅读引擎裁剪集（Kotlin/Gradle）+ `runner`（宿主验证） | 与 Flutter 构建隔离；升级流程见 `engine/LOCAL_PATCHES.md` |

## 二、设计标准（必须）

1. **动效只取 `AppMotion`**（`lib/design/motion.dart`）：contact 120 / enter 420 / exit 320 / settle 280 / coverFlight·coverReturn；曲线 ease/retract/settleCurve；spring；jelly。同一交互各页时长必须一致。
2. **反馈只走 `showFeedback` / `showError`**（`lib/design/components/feedback.dart`）：新消息替换旧的；无 context 时落到全局 `scaffoldMessengerKey`；错误用 `showError`（停留 4s），异常信息先过 `Redact.userMessage`。**删除类操作优先"可撤销"**（actionLabel: 撤销）。不得再引入其他 toast 库。
3. **主题双色都要有体现**：`accentOf`=主可见强调（标题/CTA/选中）；`companionOf`=中面积点缀（下划线、进度、标签、边线、图标点缀）。禁止只用一色；文字/图标必须用校正色，不得直接用原始亮色。
4. **弹层两种容器**：列表选择/表单 = sheet；就地操作 = 生长菜单（后续统一）。确认框统一：取消左、危险动作右、危险色 FilledButton。
5. **顶栏两种**：主标签页 = `PageHeader`；二级页 = AppBar（统一左对齐，标题 16）。不再新增第三种。
6. **空态/加载**：空态用 `empty_state.dart`；加载只用 `loading_view.dart` 的 `LoadingView` / `LoadingBar`，页面内不得直接写 `CircularProgressIndicator` / `LinearProgressIndicator`。
7. **按压**：只走 `pressable.dart` 的 `Pressable`（轻缩放 + selectionClick，无水波纹）；页面内不得直接写 `InkWell`。

## 三、交互标准（必须）

1. **点击路径：先推页、后加载**。禁止「点击 → 网络请求 → push」与「点击 → DB 查询 → push」：
   - 书/章节跳转带种子（`SearchBook`/`Book` json），目标页自行 hydrate（阅读器已合并 DB 进度；详情用 `DetailLoader` 先推壳）。
   - 失败在目标页内重试（`DetailLoader` 模式）。
2. **列表进入错峰、刷新保留旧内容**：切换分类/换源不清空当前列表；新结果到达才替换（见 `explore_model.loadBooks`）。
3. **点按要有即时反馈**：触感（`HapticFeedback.selectionClick`）或形变，禁止"点了没反应"；耗时操作必须有行内/按钮 loading。
4. **启动懒构建**：标签页首次进入才创建（`_LazyIndexedStack`）；冷启动不抢首屏（封面补齐、后台检查延后）。

## 四、功能标准（语义一致）

| 操作类 | 统一语义 |
|---|---|
| 删除/移除（书架、本地、记录、书签、缓存页删书） | 可撤销优先；不可撤销必须有确认框 + 危险色；缓存删除保留目录与进度 |
| 换源 / 体检 | 共用同一套书源排序（优选分）与超时策略；结果增量显示、可停止 |
| 搜索/发现列表 | 失败可重试（footer/空态），不静默 |
| 阅读器 | 章节头四模式统一（章首大标题+字数/时间，章中行头）；目录定位当前章；排版拖动即时预览（批次 3 待做） |

## 五、代码规范

1. 命名清晰、结构简洁、注释讲意图；不新增"可能用到"的抽象。
2. 页面/组件不得硬编码 `Duration`（除帧对齐的 16ms 类）、主题色、长段说明文案（防 AI 味：说明性小字只留功能必要信息）。
3. 异步一律 `unawaited(...)` 显式标注 fire-and-forget；跨页校正走 provider/notifier，不靠回调链。
4. 引擎边界：`lib/features/sources/engine` 只做 `SourceEngine` 通道适配；`engine/**` 是唯一书源内核。Dart 不得再实现第二套规则/JS/HTTP 引擎，也不设回落分支。
5. 测试口径：每个修复批次 `flutter analyze` 0 + 全量 `flutter test --concurrency=1`；引擎侧 `runner` 冒烟。

## 六、待收敛清单（追踪）

- 批次 3 阅读器手感（面板切换承接、换章揭示、排版即时预览）
- 批次 4 书架列表（长按菜单、错峰入场、书脊触感）
- 批次 5 Hero 封面飞行
- 批次 7 一致性（empty_state/skeleton 组件、弹层/按钮/顶栏/筛选统一、剩余散落时长清零）
- 详见 `备份\2026-11-03\2026-11-03-全面不足分析与完善计划.md`
