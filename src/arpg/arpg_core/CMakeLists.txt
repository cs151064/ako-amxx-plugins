if(NOT EXISTS "${ARPG_SDK_DIR}/amxxmodule.h")
    message(FATAL_ERROR "Missing ${ARPG_SDK_DIR}/amxxmodule.h")
endif()

if(NOT EXISTS "${ARPG_SDK_DIR}/sqlite/sqlite3.c")
    message(FATAL_ERROR "Missing ${ARPG_SDK_DIR}/sqlite/sqlite3.c")
endif()

add_library(arpg_core SHARED
    src/core/plugin.cpp
    src/core/h_export.cpp
    src/core/hooks.cpp
    src/core/arpg_core.def
    src/data/database.cpp
    ${ARPG_SDK_DIR}/sqlite/sqlite3.c
)

target_compile_features(arpg_core PRIVATE cxx_std_17)

target_include_directories(arpg_core PRIVATE
    include
    ${ARPG_SDK_DIR}
    ${ARPG_SDK_DIR}/sqlite
    ${ARPG_SDK_DIR}/hlsdk/dlls
    ${ARPG_SDK_DIR}/hlsdk/common
    ${ARPG_SDK_DIR}/hlsdk/engine
    ${ARPG_SDK_DIR}/hlsdk/pm_shared
    ${ARPG_SDK_DIR}/metamod
)

target_compile_definitions(arpg_core PRIVATE
    WIN32
    _WINDOWS
    _USRDLL
    ARPG_CORE_EXPORTS
    _CRT_SECURE_NO_WARNINGS
)

set_target_properties(arpg_core PROPERTIES
    OUTPUT_NAME arpg_core
    PREFIX ""
)

if(MSVC)
    target_compile_options(arpg_core PRIVATE /W3 /wd4996 /wd4244 /wd4305 /wd4018 /wd4267)
    target_link_options(arpg_core PRIVATE "/DEF:${CMAKE_CURRENT_LIST_DIR}/src/core/arpg_core.def")
    set_property(TARGET arpg_core PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()
