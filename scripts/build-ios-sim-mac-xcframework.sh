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

# # 设置 macOS 最低部署版本
# export MACOSX_DEPLOYMENT_TARGET=13.0

# # 构建 macOS 版本
# echo "构建 macOS 版本..."
# cd "${PROJECT_ROOT}"
# make release NUM_THREADS=$(sysctl -n hw.physicalcpu) CXXFLAGS="-mmacosx-version-min=13.0"
# 设置 macOS 最低部署版本
export MACOSX_DEPLOYMENT_TARGET=13.0

# 构建 macOS 版本
echo "构建 macOS 版本..."
cd "${PROJECT_ROOT}"
make release NUM_THREADS=$(sysctl -n hw.physicalcpu) MACOSX_DEPLOYMENT_TARGET=13.0 CXXFLAGS="-mmacosx-version-min=13.0" LDFLAGS="-mmacosx-version-min=13.0"

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
        -DCMAKE_TOOLCHAIN_FILE="${PROJECT_ROOT}/ios.toolchain.cmake" \
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
    -DCMAKE_TOOLCHAIN_FILE="${PROJECT_ROOT}/ios.toolchain.cmake" \
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

# ============ 新增：创建 module.modulemap ============
echo "创建 module.modulemap 文件..."

# 创建临时的 module.modulemap 文件
cat > "${PROJECT_ROOT}/module.modulemap" << 'EOF'
module Kuzu {
    umbrella header "kuzu.h"
    header "helpers.h"
    export *
    link "kuzu_deps"
}
EOF

# 为每个架构创建带有 module.modulemap 的临时目录
echo "准备 XCFramework 目录结构..."

# iOS 真机版本
mkdir -p "${PROJECT_ROOT}/build_ios/xcf_temp"
cp "${PROJECT_ROOT}/build_ios/lib/libkuzu_deps.a" "${PROJECT_ROOT}/build_ios/xcf_temp/"
cp -r "${PROJECT_ROOT}/src/include/c_api" "${PROJECT_ROOT}/build_ios/xcf_temp/Headers"
cp "${PROJECT_ROOT}/module.modulemap" "${PROJECT_ROOT}/build_ios/xcf_temp/"

# iOS 模拟器版本
mkdir -p "${PROJECT_ROOT}/build_ios_simulator/xcf_temp"
cp "${PROJECT_ROOT}/build_ios_simulator/lib/libkuzu_deps.a" "${PROJECT_ROOT}/build_ios_simulator/xcf_temp/"
cp -r "${PROJECT_ROOT}/src/include/c_api" "${PROJECT_ROOT}/build_ios_simulator/xcf_temp/Headers"
cp "${PROJECT_ROOT}/module.modulemap" "${PROJECT_ROOT}/build_ios_simulator/xcf_temp/"

# macOS 版本
mkdir -p "${PROJECT_ROOT}/build_macos/xcf_temp"
cp "${PROJECT_ROOT}/build_macos/lib/libkuzu_deps.a" "${PROJECT_ROOT}/build_macos/xcf_temp/"
cp -r "${PROJECT_ROOT}/src/include/c_api" "${PROJECT_ROOT}/build_macos/xcf_temp/Headers"
cp "${PROJECT_ROOT}/module.modulemap" "${PROJECT_ROOT}/build_macos/xcf_temp/"

# 使用 xcodebuild 创建 XCFramework
echo "创建 XCFramework..."
FRAMEWORK_DIR="${PROJECT_ROOT}/build/Kuzu.xcframework"
# rm -rf "${FRAMEWORK_DIR}"

xcodebuild -create-xcframework \
    -library "${PROJECT_ROOT}/build_ios/xcf_temp/libkuzu_deps.a" \
    -headers "${PROJECT_ROOT}/build_ios/xcf_temp/Headers" \
    -library "${PROJECT_ROOT}/build_ios_simulator/xcf_temp/libkuzu_deps.a" \
    -headers "${PROJECT_ROOT}/build_ios_simulator/xcf_temp/Headers" \
    -library "${PROJECT_ROOT}/build_macos/xcf_temp/libkuzu_deps.a" \
    -headers "${PROJECT_ROOT}/build_macos/xcf_temp/Headers" \
    -output "${FRAMEWORK_DIR}"

# 手动复制 module.modulemap 到 XCFramework 的各个架构目录
echo "复制 module.modulemap 到 XCFramework..."
find "${FRAMEWORK_DIR}" -type d -name "ios-*" -o -name "macos-*" | while read arch_dir; do
    cp "${PROJECT_ROOT}/module.modulemap" "${arch_dir}/"
    echo "已复制 module.modulemap 到: ${arch_dir}"
done

# 清理临时文件
echo "清理临时文件..."
rm -f "${PROJECT_ROOT}/module.modulemap"
rm -rf "${PROJECT_ROOT}/build_ios/xcf_temp"
rm -rf "${PROJECT_ROOT}/build_ios_simulator/xcf_temp"  
rm -rf "${PROJECT_ROOT}/build_macos/xcf_temp"

echo "✅ XCFramework 创建完成：${FRAMEWORK_DIR}"

# 验证 module.modulemap 是否正确添加
echo "验证 module.modulemap..."
find "${FRAMEWORK_DIR}" -name "module.modulemap" -exec echo "找到 module.modulemap: {}" \; -exec cat {} \;

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