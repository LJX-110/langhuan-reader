pluginManagement {
    repositories {
        // [本地补丁 2026-11-02] 移除 fork 私有镜像（个人环境访问返回 401）:
        // 原配置为 https://mykmp-cn-shanghai.devops.aliyuncs.com/... 带内嵌凭据；
        // kotlin-dsl 6.6.4 等插件官方门户（gradlePluginPortal）可达且存在，无需私有镜像。
        google()
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        // [本地补丁 2026-11-02] 同上: 移除 401 的 fork 私有镜像。
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    versionCatalogs {
        create("libs") {
            from(files("../gradle/libs.versions.toml"))
        }
    }
}

rootProject.name = "legado-build-logic"
