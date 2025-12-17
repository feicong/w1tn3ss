# Copyright (c) 2025-2026 fei_cong(https://github.com/feicong/feicong-course)
# AndroidConfig.cmake - Android NDK build configuration
include_guard()

# Android platform configuration helper
function(configure_android_build)
    if(NOT CMAKE_SYSTEM_NAME STREQUAL "Android")
        return()
    endif()

    message(STATUS "")
    message(STATUS "== Android Build Configuration ==")
    message(STATUS "Android ABI:          ${ANDROID_ABI}")
    message(STATUS "Android Platform:     ${ANDROID_PLATFORM}")
    message(STATUS "Android NDK:          ${ANDROID_NDK}")
    message(STATUS "Android STL:          ${ANDROID_STL}")
    message(STATUS "")

    # Disable features not supported on Android
    set(WITNESS_SCRIPT OFF CACHE BOOL "Disable scripting on Android" FORCE)
    set(BUILD_TESTS OFF CACHE BOOL "Disable tests on Android" FORCE)
    set(QBDI_TOOLS_QBDIPRELOAD OFF CACHE BOOL "Disable QBDIPreload on Android" FORCE)

    # Android-specific compile definitions
    add_compile_definitions(__ANDROID__)

    # Set Android-specific link libraries
    set(ANDROID_EXTRA_LIBS log PARENT_SCOPE)
endfunction()

# Helper to map ANDROID_ABI to WITNESS_ARCH
function(android_abi_to_witness_arch ABI RESULT_VAR)
    if(ABI STREQUAL "arm64-v8a")
        set(${RESULT_VAR} "arm64" PARENT_SCOPE)
    elseif(ABI STREQUAL "armeabi-v7a")
        set(${RESULT_VAR} "arm" PARENT_SCOPE)
    elseif(ABI STREQUAL "x86_64")
        set(${RESULT_VAR} "x64" PARENT_SCOPE)
    elseif(ABI STREQUAL "x86")
        set(${RESULT_VAR} "x86" PARENT_SCOPE)
    else()
        message(FATAL_ERROR "Unsupported Android ABI: ${ABI}")
    endif()
endfunction()

# Validate Android NDK environment
function(validate_android_ndk)
    if(NOT DEFINED ANDROID_NDK AND NOT DEFINED CMAKE_ANDROID_NDK)
        message(FATAL_ERROR "ANDROID_NDK or CMAKE_ANDROID_NDK must be set for Android builds")
    endif()

    if(DEFINED ANDROID_NDK)
        if(NOT EXISTS "${ANDROID_NDK}/build/cmake/android.toolchain.cmake")
            message(FATAL_ERROR "Invalid NDK path: ${ANDROID_NDK}")
        endif()
    endif()
endfunction()
