// :facade —— Android 引擎门面库
//
// 把 runner 验证过的「阅读引擎 + 最小 provider 注册面」搬到 Android，
// 对外只暴露 JSON in/out API（琅嬛阁以 AAR 消费，经 MethodChannel 调用）。
plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "com.langhuan.engine"
    compileSdk = 37
    defaultConfig {
        minSdk = 24
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

dependencies {
    implementation(project(":data"))
    implementation(project(":foundation"))
    implementation(libs.androidx.sqlite.framework)
    implementation(libs.kotlinx.serialization.json)
}
