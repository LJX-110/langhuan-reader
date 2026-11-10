# HarmonyOS entry NAPI bridge for Langhuan + CPF-KMP-CMP fusion renderer.
cmake_minimum_required(VERSION 3.5.0)
project(langhuan_napi)

set(NATIVERENDER_ROOT_PATH ${OHOS_SDK_NATIVE})
set(MODULE_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../..)

if (DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif ()

if (CMAKE_OHOS_ARCH_ABI STREQUAL "x86_64" OR OHOS_ARCH STREQUAL "x86_64")
    set(LANGHUAN_ABI_DIR "x86_64")
else ()
    set(LANGHUAN_ABI_DIR "arm64-v8a")
endif ()

include_directories(
    ${NATIVERENDER_ROOT_PATH}/sysroot/usr/include
        ${NATIVERENDER_ROOT_PATH}/sysroot/usr/include/${LANGHUAN_ABI_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/include/${LANGHUAN_ABI_DIR}
)

set(COMPOSE_MODULE_PATH ${MODULE_ROOT_PATH}/oh_modules/@cpf-kmp-cmp/compose)
list(APPEND CMAKE_PREFIX_PATH ${COMPOSE_MODULE_PATH})
find_package(compose REQUIRED CONFIG)

set(LANGHUAN_SHARED_LIB_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../../libs/${LANGHUAN_ABI_DIR}/liblanghuan_shared.so)

# QuickJS-NG 由 entry 原生层提供, 供 K/N cinterop 未定义符号解析。
# (mbedTLS 已于 2026-10 移除: native 加解密改为平台委托, 鸿蒙走 cryptoFramework 桥)
set(LANGHUAN_QUICKJS_NG_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../modules/quickjs/src/main/cinterop/quickjs-ng)
set(LANGHUAN_QUICKJS_NG_SRC
    ${LANGHUAN_QUICKJS_NG_DIR}/quickjs.c
    ${LANGHUAN_QUICKJS_NG_DIR}/dtoa.c
    ${LANGHUAN_QUICKJS_NG_DIR}/libregexp.c
    ${LANGHUAN_QUICKJS_NG_DIR}/libunicode.c
)

add_library(langhuan_napi SHARED
    langhuan_napi.cpp
    ${LANGHUAN_QUICKJS_NG_SRC}
)

target_include_directories(langhuan_napi PRIVATE
    ${LANGHUAN_QUICKJS_NG_DIR}
)
target_compile_definitions(langhuan_napi PRIVATE
    _GNU_SOURCE
    QUICKJS_NG_BUILD
)
set_target_properties(langhuan_napi PROPERTIES
    C_STANDARD 11
    C_STANDARD_REQUIRED ON
    C_EXTENSIONS ON
)
set_source_files_properties(${LANGHUAN_QUICKJS_NG_SRC} PROPERTIES
    COMPILE_OPTIONS "-Wno-unused-parameter;-Wno-sign-compare;-Wno-missing-field-initializers;-Wno-implicit-fallthrough"
)

if(NOT EXISTS ${LANGHUAN_SHARED_LIB_PATH})
    message(FATAL_ERROR
            "liblanghuan_shared.so not found: ${LANGHUAN_SHARED_LIB_PATH}. "
            "Run the root stageOhosNativeLibraries task with enableOhosTarget=true."
    )
endif()

target_link_libraries(langhuan_napi PUBLIC
        libace_napi.z.so
        libhilog_ndk.z.so
        ${LANGHUAN_SHARED_LIB_PATH}
        # 目标名沿用 CPF 包的兼容命名；融合渲染时它提供 NAPI/RenderNode 桥，实际 backend id=1，
        # 不创建 XComponent/EGL 自渲染面。
        compose::skikobridge
)
target_compile_definitions(langhuan_napi PRIVATE LANGHUAN_SHARED_AVAILABLE=1)

set_target_properties(langhuan_napi PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)
