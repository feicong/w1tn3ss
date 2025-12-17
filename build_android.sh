#!/bin/bash
# Copyright (c) 2025-2026 fei_cong(https://github.com/feicong/feicong-course)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

# Default configuration
BUILD_TYPE="${BUILD_TYPE:-Release}"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-24}"
BUILD_DIR_PREFIX="${BUILD_DIR_PREFIX:-build-android}"

# Supported ABIs
SUPPORTED_ABIS=("arm64-v8a" "armeabi-v7a" "x86_64" "x86")

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [ABI...]

Build w1tn3ss for Android using NDK.

Options:
    -h, --help              Show this help message
    -t, --type TYPE         Build type (Release, Debug, RelWithDebInfo) [default: Release]
    -p, --platform LEVEL    Android API level [default: 24]
    -n, --ndk PATH          Path to Android NDK (or set ANDROID_NDK / NDK_PATH env)
    -c, --clean             Clean build directory before building
    -j, --jobs N            Number of parallel build jobs [default: auto]
    --all                   Build for all supported ABIs

ABIs:
    arm64-v8a               ARM64 (64-bit)
    armeabi-v7a             ARM (32-bit)
    x86_64                  x86-64 (64-bit)
    x86                     x86 (32-bit)

Examples:
    $0 arm64-v8a                    # Build for ARM64
    $0 --all                        # Build for all ABIs
    $0 -t Debug arm64-v8a x86_64    # Debug build for ARM64 and x86_64
    $0 -n /path/to/ndk arm64-v8a    # Specify NDK path

Environment Variables:
    ANDROID_NDK             Path to Android NDK
    NDK_PATH                Alternative path to Android NDK
    ANDROID_SDK_ROOT        Path to Android SDK (NDK looked up in ndk-bundle/)
    BUILD_TYPE              Build type [default: Release]
    ANDROID_PLATFORM        Android API level [default: 24]
EOF
    exit 0
}

# Find NDK path
find_ndk() {
    local ndk_path=""

    # Check command line argument first
    if [ -n "${NDK_ARG}" ]; then
        ndk_path="${NDK_ARG}"
    elif [ -n "${ANDROID_NDK}" ]; then
        ndk_path="${ANDROID_NDK}"
    elif [ -n "${NDK_PATH}" ]; then
        ndk_path="${NDK_PATH}"
    elif [ -n "${ANDROID_SDK_ROOT}" ]; then
        # Try common NDK locations within SDK
        for dir in "ndk-bundle" "ndk" "ndk/"*; do
            if [ -d "${ANDROID_SDK_ROOT}/${dir}" ]; then
                ndk_path="${ANDROID_SDK_ROOT}/${dir}"
                break
            fi
        done
    elif [ -n "${ANDROID_HOME}" ]; then
        for dir in "ndk-bundle" "ndk" "ndk/"*; do
            if [ -d "${ANDROID_HOME}/${dir}" ]; then
                ndk_path="${ANDROID_HOME}/${dir}"
                break
            fi
        done
    fi

    # macOS common paths
    if [ -z "${ndk_path}" ] && [ "$(uname)" = "Darwin" ]; then
        local macos_paths=(
            "$HOME/Library/Android/sdk/ndk-bundle"
            "$HOME/Library/Android/sdk/ndk"
            "/usr/local/share/android-ndk"
        )
        for path in "${macos_paths[@]}"; do
            if [ -d "${path}" ]; then
                # If it's the ndk directory, find the latest version
                if [ -d "${path}" ] && [ "$(basename "${path}")" = "ndk" ]; then
                    ndk_path=$(ls -1d "${path}"/* 2>/dev/null | sort -V | tail -1)
                else
                    ndk_path="${path}"
                fi
                break
            fi
        done
    fi

    # Linux common paths
    if [ -z "${ndk_path}" ] && [ "$(uname)" = "Linux" ]; then
        local linux_paths=(
            "$HOME/Android/Sdk/ndk-bundle"
            "$HOME/Android/Sdk/ndk"
            "/opt/android-ndk"
        )
        for path in "${linux_paths[@]}"; do
            if [ -d "${path}" ]; then
                if [ "$(basename "${path}")" = "ndk" ]; then
                    ndk_path=$(ls -1d "${path}"/* 2>/dev/null | sort -V | tail -1)
                else
                    ndk_path="${path}"
                fi
                break
            fi
        done
    fi

    if [ -z "${ndk_path}" ]; then
        log_error "Android NDK not found!"
        log_error "Please set ANDROID_NDK environment variable or use --ndk option"
        exit 1
    fi

    if [ ! -f "${ndk_path}/build/cmake/android.toolchain.cmake" ]; then
        log_error "Invalid NDK path: ${ndk_path}"
        log_error "Cannot find: ${ndk_path}/build/cmake/android.toolchain.cmake"
        exit 1
    fi

    echo "${ndk_path}"
}

# Map ABI to WITNESS_ARCH
abi_to_arch() {
    case "$1" in
        arm64-v8a)    echo "arm64" ;;
        armeabi-v7a)  echo "arm" ;;
        x86_64)       echo "x64" ;;
        x86)          echo "x86" ;;
        *)            log_error "Unknown ABI: $1"; exit 1 ;;
    esac
}

# Build for a single ABI
build_abi() {
    local abi="$1"
    local ndk_path="$2"
    local arch=$(abi_to_arch "${abi}")
    local build_dir="${PROJECT_ROOT}/${BUILD_DIR_PREFIX}-${abi}"

    log_info "Building for ${abi} (${arch})..."
    log_info "  Build directory: ${build_dir}"
    log_info "  Build type: ${BUILD_TYPE}"
    log_info "  Android platform: ${ANDROID_PLATFORM}"

    if [ "${CLEAN_BUILD}" = "1" ] && [ -d "${build_dir}" ]; then
        log_info "  Cleaning build directory..."
        rm -rf "${build_dir}"
    fi

    mkdir -p "${build_dir}"
    cd "${build_dir}"

    cmake "${PROJECT_ROOT}" \
        -G Ninja \
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
        -DCMAKE_TOOLCHAIN_FILE="${ndk_path}/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI="${abi}" \
        -DANDROID_PLATFORM="${ANDROID_PLATFORM}" \
        -DANDROID_STL=c++_static \
        -DWITNESS_ARCH="${arch}" \
        -DWITNESS_SCRIPT=OFF \
        -DBUILD_TESTS=OFF

    local jobs_arg=""
    if [ -n "${BUILD_JOBS}" ]; then
        jobs_arg="-j${BUILD_JOBS}"
    fi

    cmake --build . --parallel ${jobs_arg}

    log_info "Build completed for ${abi}"
    log_info "  Output: ${build_dir}"
}

# Main
main() {
    local abis=()
    local build_all=0
    CLEAN_BUILD=0
    BUILD_JOBS=""
    NDK_ARG=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                ;;
            -t|--type)
                BUILD_TYPE="$2"
                shift 2
                ;;
            -p|--platform)
                ANDROID_PLATFORM="$2"
                shift 2
                ;;
            -n|--ndk)
                NDK_ARG="$2"
                shift 2
                ;;
            -c|--clean)
                CLEAN_BUILD=1
                shift
                ;;
            -j|--jobs)
                BUILD_JOBS="$2"
                shift 2
                ;;
            --all)
                build_all=1
                shift
                ;;
            arm64-v8a|armeabi-v7a|x86_64|x86)
                abis+=("$1")
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Determine which ABIs to build
    if [ "${build_all}" = "1" ]; then
        abis=("${SUPPORTED_ABIS[@]}")
    elif [ ${#abis[@]} -eq 0 ]; then
        # Default to arm64-v8a
        abis=("arm64-v8a")
    fi

    # Find NDK
    local ndk_path=$(find_ndk)
    log_info "Using NDK: ${ndk_path}"

    # Check for ninja
    if ! command -v ninja &> /dev/null; then
        log_error "ninja not found. Please install ninja-build."
        exit 1
    fi

    # Build each ABI
    for abi in "${abis[@]}"; do
        build_abi "${abi}" "${ndk_path}"
    done

    log_info "All builds completed successfully!"
    log_info "Output directories:"
    for abi in "${abis[@]}"; do
        echo "  ${BUILD_DIR_PREFIX}-${abi}/"
    done
}

main "$@"
