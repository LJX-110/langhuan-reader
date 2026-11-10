cmake_minimum_required(VERSION 3.18)
project(langhuan_smtc C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

add_library(langhuan_smtc SHARED smtc_bridge.c)

if (WIN32)
    # 去 lib 前缀: 输出 langhuan_smtc.dll; Windows 下 DLL 是 RUNTIME 产物, 指到 LIBRARY 输出目录
    set_target_properties(langhuan_smtc PROPERTIES
            PREFIX ""
            RUNTIME_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}"
    )
    target_compile_definitions(langhuan_smtc PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN INITGUID)
    target_link_libraries(langhuan_smtc PRIVATE ole32)
endif ()
