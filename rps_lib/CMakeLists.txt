cmake_minimum_required(VERSION 3.7 FATAL_ERROR)

set (CMAKE_CXX_STANDARD 17)
set(CMAKE_OSX_ARCHITECTURES "x86_64;arm64" )


project(rps_lib VERSION 0.2.0 LANGUAGES CXX)
add_library(rps_lib SHARED rps.cpp rps.def)
add_executable(rps_test rps.cpp)


set_target_properties(rps_lib PROPERTIES
    LINK_FLAGS_RELEASE -x
    PUBLIC_HEADER rps.h
    VERSION ${PROJECT_VERSION}
    SOVERSION 1
    OUTPUT_NAME "rps"
    # XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Hex_Identity_ID_Goes_Here"
)