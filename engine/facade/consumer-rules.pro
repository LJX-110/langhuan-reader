# 引擎（阅读裁剪集）反射面较广：Room / kotlinx-serialization / JS 桥 / JNI。
# 先整体保留（正确性优先），后续按真机实测逐步收窄。
-keep class io.legado.** { *; }
-keep class com.script.** { *; }
-keep class com.langhuan.engine.** { *; }
-dontwarn io.legado.**
-dontwarn com.script.**
