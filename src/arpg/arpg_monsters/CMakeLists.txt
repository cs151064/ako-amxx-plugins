add_library(arpg_monsters SHARED)

target_compile_features(arpg_monsters PRIVATE cxx_std_14)

target_include_directories(arpg_monsters PRIVATE
    src/core
    src/base
    src/monsters
    ${ARPG_SDK_DIR}/hlsdk/dlls
    ${ARPG_SDK_DIR}/hlsdk/common
    ${ARPG_SDK_DIR}/hlsdk/engine
    ${ARPG_SDK_DIR}/hlsdk/pm_shared
    ${ARPG_SDK_DIR}/metamod
)

target_compile_definitions(arpg_monsters PRIVATE
    WIN32
    _WINDOWS
    _USRDLL
    ARPG_MONSTERS_EXPORTS
    strcasecmp=stricmp
    strncasecmp=_strnicmp
)

target_sources(arpg_monsters PRIVATE
    src/core/monster_api.cpp
    src/core/dllapi.cpp
    src/core/monster_config.cpp
    src/core/globalreplace.cpp
    src/core/h_export.cpp
    src/core/monster_mm.def
    src/base/AI_BaseNPC_Schedule.cpp
    src/base/animating.cpp
    src/base/animation.cpp
    src/base/cmbase.cpp
    src/base/combat.cpp
    src/base/defaultai.cpp
    src/base/effects.cpp
    src/base/explode.cpp
    src/base/ggrenade.cpp
    src/base/h_ai.cpp
    src/base/monsterstate.cpp
    src/base/monsters.cpp
    src/base/music.cpp
    src/base/nodes.cpp
    src/base/ripent.cpp
    src/base/skill.cpp
    src/base/sound.cpp
    src/base/subs.cpp
    src/base/util.cpp
    src/base/weapons.cpp
    src/monsters/hutao.cpp
)

set_target_properties(arpg_monsters PROPERTIES
    OUTPUT_NAME arpg_monsters
    PREFIX ""
)

if(MSVC)
    target_compile_options(arpg_monsters PRIVATE /W3 /wd4996 /wd4244 /wd4305 /wd4018)
    target_link_options(arpg_monsters PRIVATE "/DEF:${CMAKE_CURRENT_LIST_DIR}/src/core/monster_mm.def")
    set_property(TARGET arpg_monsters PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()
