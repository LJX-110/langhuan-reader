// :ui-model —— UI 状态模型层 (P3 架构解耦)。
//
// 职责: 只放页面展示所需的纯数据模型 (BookItemUi / ChapterItemUi / GroupUi /
// ShelfStateUi), 不依赖 :data / :core / Compose。:ui 的页面与组件只接收这里的
// 模型; 「实体 → UI 模型」的纯函数映射由持有数据的宿主层完成。
plugins {
    id("langhuan.kmp.library")
}

val isMacHost = System.getProperty("os.name").startsWith("Mac", ignoreCase = true)
val enableIosTarget = providers.gradleProperty("enableIosTarget").orNull?.toBoolean() ?: isMacHost
val enableOhosTarget = providers.gradleProperty("enableOhosTarget").orNull?.toBoolean() ?: false

kotlin {
    jvm()

    android {
        namespace = "com.langhuan.reader.uimodel"
        compileSdk = 37
        minSdk = 24
    }

    if (enableIosTarget) {
        iosArm64()
        iosSimulatorArm64()
    }

    // ohosArm64 只存在于 CPF 分支 KGP, 交给 build-logic 的约定插件声明 (与 :foundation 同款)。
    if (enableOhosTarget) {
        pluginManager.apply("langhuan.kmp.ohos")
    }
}
