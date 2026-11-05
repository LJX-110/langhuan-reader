import org.gradle.api.publish.maven.MavenPublication

plugins {
    alias(libs.plugins.android.library)
    id("maven-publish")
}

android {
    namespace = "com.script.quickjs.nativebridge"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
        ndk {
            // 与 app splits 对齐: 只编 arm64-v8a + armeabi-v7a, x86 系不再编译
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
        externalNativeBuild {
            cmake {
                arguments += "-DANDROID_STL=c++_static"
                cppFlags += listOf("-std=c++17", "-fvisibility=hidden")
                cFlags += "-fvisibility=hidden"
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    lint {
        checkDependencies = true
        // x86_64 ABI 是刻意决策: 与 :app splits 对齐, 只编 arm64-v8a + armeabi-v7a
        disable += "ChromeOsAbiSupport"
    }
    publishing {
        singleVariant("release") {
            withSourcesJar()
        }
    }
}

// 本地 Maven 发布（App 消费）：纯 AGP 模块需显式创建 release publication
afterEvaluate {
    publishing {
        publications {
            create<MavenPublication>("release") {
                from(components["release"])
            }
        }
    }
}
