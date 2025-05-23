#!/bin/bash

set -e

# 获取项目根目录的绝对路径
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)

# 创建构建目录（如果不存在）
mkdir -p "${PROJECT_ROOT}/build_ios/lib"
mkdir -p "${PROJECT_ROOT}/build_ios_simulator/lib"
mkdir -p "${PROJECT_ROOT}/build_macos/lib"

# 获取 CPU 核心数
CPU_CORES=$(sysctl -n hw.ncpu)

# 设置 macOS 最低部署版本
export MACOSX_DEPLOYMENT_TARGET=13.0

# # 构建 macOS 版本
echo "构建 macOS 版本..."
cd "${PROJECT_ROOT}"
make release NUM_THREADS=$(sysctl -n hw.physicalcpu)

# 移动 macOS 构建产物到指定目录
echo "移动 macOS 构建产物..."
mkdir -p "${PROJECT_ROOT}/build_macos/lib"
find "${PROJECT_ROOT}/build/release" -name '*.a' -exec cp {} "${PROJECT_ROOT}/build_macos/lib/" \;

# 使用 libtool 打包 macOS 版本
echo "打包 macOS 版本..."
cd "${PROJECT_ROOT}/build_macos/lib"
LIBS_TO_MERGE=(
"libantlr4_runtime.a"
"libantlr4_cypher.a"
"libbrotlicommon.a"
"libbrotlidec.a"
"libbrotlienc.a"
"libfastpfor.a"
"liblz4.a"
"libmbedtls.a"
"libminiz.a"
"libparquet.a"
"libre2.a"
"libroaring_bitmap.a"
"libsimsimd.a"
"libsnappy.a"
"libthrift.a"
"libutf8proc.a"
"libyyjson.a"
"libzstd.a"
"libkuzu.a"
)
libtool -static -o libkuzu_deps.a ${LIBS_TO_MERGE[@]} 2>&1 | grep -v "warning: duplicate member name"

# 构建真机版本
echo "构建 iOS 真机版本..."
export IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
export IOS_ARCH=arm64
export IOS_PLATFORM=iPhoneOS
export IOS_DEPLOYMENT_TARGET=13.0

cd "${PROJECT_ROOT}/build_ios"

# 只在第一次或 CMakeLists.txt 变化时重新配置
if [ ! -f "CMakeCache.txt" ] || [ "${PROJECT_ROOT}/CMakeLists.txt" -nt "CMakeCache.txt" ]; then
    cmake "${PROJECT_ROOT}" \
        -G Ninja \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DPLATFORM=OS \
        -DCMAKE_OSX_ARCHITECTURES=${IOS_ARCH} \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=${IOS_DEPLOYMENT_TARGET} \
        -DCMAKE_OSX_SYSROOT=${IOS_SDK_PATH} \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="/Users/gl/toolchains/ios.toolchain.cmake" \
        -DENABLE_WERROR=OFF \
        -DBUILD_SHELL=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_BENCHMARK=OFF \
        -DBUILD_WASM=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY="${PROJECT_ROOT}/build_ios/lib"
fi

ninja -j${CPU_CORES}

# 使用 libtool 打包真机版本
echo "打包 iOS 真机版本..."
cd "${PROJECT_ROOT}/build_ios/lib"
libtool -static -o libkuzu_deps.a ${LIBS_TO_MERGE[@]} 2>&1 | grep -v "warning: duplicate member name"

# 构建模拟器版本
echo "构建 iOS 模拟器版本..."
export IOS_SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
export IOS_PLATFORM=iPhoneSimulator
export IOS_DEPLOYMENT_TARGET=13.0

echo "模拟器 SDK 路径: ${IOS_SDK_PATH}"
echo "目标平台: ${IOS_PLATFORM}"

cd "${PROJECT_ROOT}/build_ios_simulator"


cmake "${PROJECT_ROOT}" \
    -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DPLATFORM=SIMULATORARM64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=${IOS_DEPLOYMENT_TARGET} \
    -DCMAKE_OSX_SYSROOT=${IOS_SDK_PATH} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="/Users/gl/toolchains/ios.toolchain.cmake" \
    -DENABLE_WERROR=OFF \
    -DBUILD_SHELL=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_BENCHMARK=OFF \
    -DBUILD_WASM=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY="${PROJECT_ROOT}/build_ios_simulator/lib" \
    -DCMAKE_VERBOSE_MAKEFILE=ON

ninja -j${CPU_CORES}

# 使用 libtool 打包模拟器版本
echo "打包 iOS 模拟器版本..."
cd "${PROJECT_ROOT}/build_ios_simulator/lib"
libtool -static -o libkuzu_deps.a ${LIBS_TO_MERGE[@]} 2>&1 | grep -v "warning: duplicate member name"

# 使用 xcodebuild 创建 XCFramework
echo "创建 XCFramework..."
FRAMEWORK_DIR="${PROJECT_ROOT}/build/Kuzu.xcframework"
# rm -rf "${FRAMEWORK_DIR}"

xcodebuild -create-xcframework \
    -library "${PROJECT_ROOT}/build_ios/lib/libkuzu_deps.a" \
    -headers "${PROJECT_ROOT}/src/include/c_api" \
    -library "${PROJECT_ROOT}/build_ios_simulator/lib/libkuzu_deps.a" \
    -headers "${PROJECT_ROOT}/src/include/c_api" \
    -library "${PROJECT_ROOT}/build_macos/lib/libkuzu_deps.a" \
    -headers "${PROJECT_ROOT}/src/include/c_api" \
    -output "${FRAMEWORK_DIR}"

echo "✅ XCFramework 创建完成：${FRAMEWORK_DIR}"

# 列出生成的静态库
echo "macOS 版本静态库列表："
find "${PROJECT_ROOT}/build_macos/lib" -name '*.a' -exec ls -lh {} \;

echo "真机版本静态库列表："
find "${PROJECT_ROOT}/build_ios/lib" -name '*.a' -exec ls -lh {} \;

echo "模拟器版本静态库列表："
find "${PROJECT_ROOT}/build_ios_simulator/lib" -name '*.a' -exec ls -lh {} \;

# 验证架构
echo "验证 macOS 版本架构："
lipo -info "${PROJECT_ROOT}/build_macos/lib/libkuzu_deps.a"

echo "验证真机版本架构："
lipo -info "${PROJECT_ROOT}/build_ios/lib/libkuzu_deps.a"

echo "验证模拟器版本架构："
lipo -info "${PROJECT_ROOT}/build_ios_simulator/lib/libkuzu_deps.a"