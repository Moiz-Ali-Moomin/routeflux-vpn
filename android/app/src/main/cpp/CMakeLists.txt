cmake_minimum_required(VERSION 3.18.1)

project(native)

# Import prebuilt Go tun2socks
add_library(
    tun2socks
    SHARED
    IMPORTED
)

set_target_properties(
    tun2socks
    PROPERTIES
    IMPORTED_LOCATION
    ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libtun2socks.so
)

# Helper native lib for process management
add_library(native_utils SHARED tun2socks_jni.c)

target_link_libraries(native_utils log)
