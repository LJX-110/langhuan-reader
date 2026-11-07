// 琅嬛阁引擎裁剪集 —— 设置脚本（裁剪自上游 huajideshutiao/legado master@d31c0a2）
// 只保留引擎依赖闭包：foundation <- data，modules/{js-api, quickjs(+android-native/processor/test), rjpath}
// 本地改动见 LOCAL_PATCHES.md
pluginManagement {
    includeBuild("build-logic")
    repositories {
        // 官方仓库优先：Aliyun 镜像对部分插件 marker（如 KSP 2.3.11）返回 502，
        // Gradle 会把 5xx 当仓库故障而不继续兜底；国内镜像仍保留作回退。
        google()
        mavenCentral()
        gradlePluginPortal()
        maven("https://maven.aliyun.com/repository/public")
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/gradle-plugin")
        maven { url = uri("https://jitpack.io") }
        maven("https://maven.eazytec-cloud.com/nexus/repository/maven-public/")
        mavenLocal()
    }
}
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        // JitPack 的同坐标 XMLUtil 发布缺少 iOS 变体；该组只使用 Maven Central 的完整发布。
        exclusiveContent {
            forRepository { mavenCentral() }
            filter { includeGroup("io.github.pdvrieze.xmlutil") }
        }
        // 官方仓库优先（同 pluginManagement：镜像 5xx 会中断解析），国内镜像兜底。
        google()
        mavenCentral()
        maven("https://maven.aliyun.com/repository/public")
        maven("https://maven.aliyun.com/repository/google")
        maven { url = uri("https://jitpack.io") }
        maven("https://maven.eazytec-cloud.com/nexus/repository/maven-public/")
        mavenLocal()
    }
}

rootProject.name = "langhuan-engine"

include(":modules:js-api")
include(":modules:quickjs")
include(":modules:quickjs-test")
include(":modules:quickjs-android-native")
include(":modules:quickjs-processor")
include(":modules:rjpath")
include(":foundation")
include(":data")
// 宿主验证 runner（JVM）：用便携版 quickjs DLL 在本机跑通引擎 JS/规则管线
include(":runner")
// Android facade：把同一套引擎注册面搬进 Android（后续以 AAR 供琅嬛阁消费）
include(":facade")
