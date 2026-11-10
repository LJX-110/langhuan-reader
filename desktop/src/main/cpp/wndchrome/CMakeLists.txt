cmake_minimum_required(VERSION 3.13)
project(langhuan_wndchrome C)

set(CMAKE_C_STANDARD 99)
add_definitions(-DUNICODE -D_UNICODE -DWIN32_LEAN_AND_MEAN)

add_library(langhuan_wndchrome SHARED wndchrome.c)

# 输出名固定 langhuan_wndchrome.dll (不要 lib 前缀); 输出目录由 gradle 传
# -DCMAKE_RUNTIME_OUTPUT_DIRECTORY / -DCMAKE_LIBRARY_OUTPUT_DIRECTORY
set_target_properties(langhuan_wndchrome PROPERTIES PREFIX "")

# user32/gdi32: 窗口与绘制; comctl32: SetWindowSubclass (与 AWT 同机制); dwmapi: 按钮区尺寸查询;
# shell32: 任务栏 auto-hide 状态
target_link_libraries(langhuan_wndchrome PRIVATE user32 gdi32 comctl32 dwmapi shell32)
