cmake_minimum_required(VERSION 3.15 FATAL_ERROR)

# Pre-project() settings. APPLE/WIN32/UNIX aren't defined yet, so the
# CMAKE_OSX_* variables are set unconditionally — they're ignored on
# non-Apple platforms.
set(CMAKE_OSX_ARCHITECTURES "x86_64;arm64" CACHE STRING
    "Build universal macOS binary" FORCE)
set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15" CACHE STRING
    "Minimum macOS version" FORCE)

project(rps_lib
    VERSION 0.10.0
    DESCRIPTION "Native helper for rps (Run Pubspec Script)"
    LANGUAGES CXX)

# Default to Release when no build type is specified.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# rps.def is an MSVC module definition file; only meaningful on Windows.
if(WIN32)
    add_library(rps_lib SHARED rps.cpp rps.def)
else()
    add_library(rps_lib SHARED rps.cpp)
endif()

add_executable(rps_test rps.cpp)

# Statically link the MSVC runtime so the dll has no external VCRT dep.
if(MSVC)
    set_property(TARGET rps_lib PROPERTY
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    set_property(TARGET rps_test PROPERTY
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

set_target_properties(rps_lib PROPERTIES
    PUBLIC_HEADER rps.h
    VERSION ${PROJECT_VERSION}
    SOVERSION 1
    OUTPUT_NAME "rps")

# Strip local symbols from release builds on Unix-like linkers.
if(NOT MSVC)
    target_link_options(rps_lib PRIVATE $<$<CONFIG:Release>:-Wl,-x>)
endif()
