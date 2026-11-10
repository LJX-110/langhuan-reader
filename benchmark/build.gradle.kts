// Android Baseline Profile 生成模块 (对照 Now in Android 官方 benchmarks 模块写法)。
// 插件/工具链/flavor 对齐/targetProjectPath 由 build-logic 的 langhuan.android.benchmark 约定提供;
// com.android.test 已由 androidx.baselineprofile 带入插件 classpath, 此处不得再声明版本。
plugins {
    id("langhuan.android.benchmark")
}

android {
    namespace = "com.langhuan.reader.benchmark"
}

dependencies {
    implementation(libs.androidx.benchmark.macro)
    implementation(libs.androidx.junit)
    implementation(libs.androidx.runner)
    implementation(libs.androidx.uiautomator)
}
