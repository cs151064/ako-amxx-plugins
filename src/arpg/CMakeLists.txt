cmake_minimum_required(VERSION 3.20)
project(ako_arpg LANGUAGES C CXX)

get_filename_component(ARPG_WORKSPACE_DIR "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(ARPG_DIST_DIR "${ARPG_WORKSPACE_DIR}/dist")
set(ARPG_SDK_DIR "${CMAKE_CURRENT_LIST_DIR}/sdk")

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${ARPG_DIST_DIR}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG "${ARPG_DIST_DIR}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE "${ARPG_DIST_DIR}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "${ARPG_DIST_DIR}")

option(ARPG_BUILD_CORE "Build arpg_core when AMXX module and SQLite SDK files are present" OFF)
option(ARPG_BUILD_MONSTERS "Build Hutao-only arpg_monsters" ON)

if(ARPG_BUILD_CORE)
    add_subdirectory(arpg_core)
endif()

if(ARPG_BUILD_MONSTERS)
    add_subdirectory(arpg_monsters)
endif()
