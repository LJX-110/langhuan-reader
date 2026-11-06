// 琅嬛阁引擎裁剪集 —— 根构建脚本（裁剪自上游 huajideshutiao/legado master@d31c0a2）
// 上游的 ohos 打包 / iOS 版本同步任务已移除（本项目不需要）；本地改动见 LOCAL_PATCHES.md

import org.gradle.api.publish.PublishingExtension

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

// ============ 本地 Maven 发布（Flutter App 消费）============
// 引擎模块统一 group/version，发布到 langhuan/android/engine-repo（随仓库提交，App 与 CI 直接消费）。
// 引擎有改动后重新发布并提交 engine-repo：
//   engine> gradlew -g E:\WorkSpace\Novel\.gradle-home publishAllPublicationsToLocalRepo
subprojects {
    group = "com.langhuan.engine"
    version = "0.3.0"
    // 元数据编译的 KSP 在 :data 上有已知失败（Room @Query 注解解析），
    // 且 App 消费只走 Android 变体；关闭该任务，元数据 JAR 仍可正常产出。
    tasks.matching { it.name == "kspCommonMainKotlinMetadata" }.configureEach {
        enabled = false
    }
    plugins.withId("maven-publish") {
        extensions.configure<PublishingExtension> {
            repositories {
                maven {
                    name = "localRepo"
                    url = uri(rootProject.file("../android/engine-repo"))
                }
            }
        }
        // 瘦身：App 只消费 Android 变体，JVM 发布任务全部跳过。
        tasks.matching { it.name.startsWith("publishJvmPublication") }.configureEach {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
