// 琅嬛阁引擎裁剪集 —— 根构建脚本（裁剪自上游 huajideshutiao/legado master@d31c0a2）
// 上游的 ohos 打包 / iOS 版本同步任务已移除（本项目不需要）；本地改动见 LOCAL_PATCHES.md

plugins {
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.android.kmp.library) apply false
    alias(libs.plugins.kotlin.multiplatform) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.room) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}

subprojects {
    configurations.all {
        // 沿用上游：彻底移除 Material Icons 依赖（体积控制）。
        exclude(group = "androidx.compose.material", module = "material-icons-core")
        exclude(group = "androidx.compose.material", module = "material-icons-extended")
        exclude(group = "org.jetbrains.compose.material", module = "material-icons-core")
        exclude(group = "org.jetbrains.compose.material", module = "material-icons-core-desktop")
        exclude(group = "org.jetbrains.compose.material", module = "material-icons-extended")
        exclude(group = "org.jetbrains.compose.material", module = "material-icons-extended-desktop")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
