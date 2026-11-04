// :runner —— 引擎宿主验证 runner（纯 JVM）
//
// 目的：在 Windows 宿主上以最小注册集跑通「规则引擎 + QuickJS + java.* 绑定」，
// 用于 M0/M1 的快速迭代（真机之前的先行验证）。
// quickjs 原生库用官方桌面便携包里提取的 legado_quickjs.dll（runner/native/）。
plugins {
    alias(libs.plugins.kotlin.jvm)
    application
}

kotlin {
    jvmToolchain(21)
}

dependencies {
    implementation(project(":data"))
    implementation(project(":modules:quickjs"))
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.okhttp)
}

application {
    mainClass.set("io.legado.runner.MainKt")
}
