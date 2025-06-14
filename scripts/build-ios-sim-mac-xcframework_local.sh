#!/bin/bash

set -e

# 获取项目根目录的绝对路径
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)

# ========== 新增：扩展构建目录管理 ==========
echo "🧹 清理扩展构建缓存，避免平台混合..."
# 清理所有扩展的构建目录，避免不同平台的对象文件混合
find "${PROJECT_ROOT}/extension" -name "build" -type d -exec rm -rf {} + 2>/dev/null || true

# 确保扩展构建目录在每个平台构建时都是干净的
clean_extension_builds() {
    local platform_suffix="$1"
    echo "为$platform_suffix平台清理扩展构建..."
    
    for ext_dir in "${PROJECT_ROOT}/extension"/*; do
        if [ -d "$ext_dir" ]; then
            ext_name=$(basename "$ext_dir")
            # 为每个平台创建独立的扩展构建目录
            if [ -d "${ext_dir}/build" ]; then
                rm -rf "${ext_dir}/build"
            fi
        fi
    done
}

# ========== 原有检查逻辑 ==========
# 检查扩展配置
echo "检查扩展配置..."
if grep -q "^add_static_link_extension" "${PROJECT_ROOT}/extension/extension_config.cmake"; then
    echo "✅ 扩展已启用，将编译所有插件"
    EXTENSIONS_ENABLED=true
else
    echo "⚠️  扩展未启用，只编译基础功能"
    EXTENSIONS_ENABLED=false
fi

# 创建构建目录（如果不存在）
mkdir -p "${PROJECT_ROOT}/build_ios/lib"
mkdir -p "${PROJECT_ROOT}/build_ios_simulator/lib"
mkdir -p "${PROJECT_ROOT}/build_macos/lib"

# 获取 CPU 核心数
CPU_CORES=$(sysctl -n hw.ncpu)

# 设置 macOS 最低部署版本
export MACOSX_DEPLOYMENT_TARGET=13.0

# ========== macOS 构建 ==========
echo "构建 macOS 版本..."
clean_extension_builds "macOS"

cd "${PROJECT_ROOT}"
make release NUM_THREADS=$(sysctl -n hw.physicalcpu) MACOSX_DEPLOYMENT_TARGET=13.0 CXXFLAGS="-mmacosx-version-min=13.0" LDFLAGS="-mmacosx-version-min=13.0"

# 移动 macOS 构建产物到指定目录
echo "移动 macOS 构建产物..."
mkdir -p "${PROJECT_ROOT}/build_macos/lib"
find "${PROJECT_ROOT}/build/release" -name '*.a' -exec cp {} "${PROJECT_ROOT}/build_macos/lib/" \;

# 使用 libtool 打包 macOS 版本
echo "打包 macOS 版本..."
cd "${PROJECT_ROOT}/build_macos/lib"

# 基础库文件
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

# 扩展库文件（如果存在则添加）
EXTENSION_LIBS=(
"libkuzu_algo_static_extension.a"
"libkuzu_delta_static_extension.a"
"libkuzu_duckdb_static_extension.a"
"libkuzu_fts_static_extension.a"
"libkuzu_httpfs_static_extension.a"
"libkuzu_iceberg_static_extension.a"
"libkuzu_json_static_extension.a"
"libkuzu_neo4j_static_extension.a"
"libkuzu_postgres_static_extension.a"
"libkuzu_sqlite_static_extension.a"
"libkuzu_unity_catalog_static_extension.a"
"libkuzu_vector_static_extension.a"
)

# 检查扩展库是否存在并添加到合并列表
echo "检查可用的扩展库..."
for ext_lib in "${EXTENSION_LIBS[@]}"; do
    if [ -f "${ext_lib}" ]; then
        echo "✅ 找到扩展库: ${ext_lib}"
        LIBS_TO_MERGE+=("${ext_lib}")
    else
        echo "⚠️  未找到扩展库: ${ext_lib}"
    fi
done

echo "将要合并的库文件总数: ${#LIBS_TO_MERGE[@]}"
libtool -static -o libkuzu_deps.a ${LIBS_TO_MERGE[@]} 2>&1 | grep -v "warning: duplicate member name"

# ========== iOS 真机构建 ==========
echo "构建 iOS 真机版本..."
clean_extension_builds "iOS真机"

export IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
export IOS_ARCH=arm64
export IOS_PLATFORM=iPhoneOS  
export IOS_DEPLOYMENT_TARGET=13.0

cd "${PROJECT_ROOT}/build_ios"

# 只在第一次或 CMakeLists.txt 变化时重新配置
if [ ! -f "CMakeCache.txt" ] || [ "${PROJECT_ROOT}/CMakeLists.txt" -nt "CMakeCache.txt" ]; then
    # 清理旧的构建缓存以避免工具链冲突
    rm -f CMakeCache.txt
    
    cmake "${PROJECT_ROOT}" \
        -G Ninja \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DPLATFORM=OS64 \
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

# 重新检查真机版本的扩展库
LIBS_TO_MERGE_IOS=("${LIBS_TO_MERGE[@]}")
LIBS_TO_MERGE_IOS=()
for lib in "${LIBS_TO_MERGE[@]}"; do
    if [ -f "${lib}" ]; then
        LIBS_TO_MERGE_IOS+=("${lib}")
    fi
done

echo "iOS真机版本将要合并的库文件总数: ${#LIBS_TO_MERGE_IOS[@]}"
libtool -static -o libkuzu_deps.a ${LIBS_TO_MERGE_IOS[@]} 2>&1 | grep -v "warning: duplicate member name"

# ========== iOS 模拟器构建 ==========
echo "构建 iOS 模拟器版本..."
clean_extension_builds "iOS模拟器"

export IOS_SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
export IOS_PLATFORM=iPhoneSimulator
export IOS_DEPLOYMENT_TARGET=13.0

echo "模拟器 SDK 路径: ${IOS_SDK_PATH}"
echo "目标平台: ${IOS_PLATFORM}"

cd "${PROJECT_ROOT}/build_ios_simulator"

# 清理旧的构建缓存以避免工具链冲突
rm -f CMakeCache.txt

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
    -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY="${PROJECT_ROOT}/build_ios_simulator/lib"

ninja -j${CPU_CORES}

# 使用 libtool 打包模拟器版本
echo "打包 iOS 模拟器版本..."
cd "${PROJECT_ROOT}/build_ios_simulator/lib"

# 重新检查模拟器版本的扩展库
LIBS_TO_MERGE_SIM=()
for lib in "${LIBS_TO_MERGE[@]}"; do
    if [ -f "${lib}" ]; then
        LIBS_TO_MERGE_SIM+=("${lib}")
    fi
done

echo "iOS模拟器版本将要合并的库文件总数: ${#LIBS_TO_MERGE_SIM[@]}"
libtool -static -o libkuzu_deps.a ${LIBS_TO_MERGE_SIM[@]} 2>&1 | grep -v "warning: duplicate member name"

# ============ 修复：清理和重新创建 XCFramework ============
echo "准备创建 XCFramework..."

# 完全删除旧的 XCFramework（如果存在）
FRAMEWORK_DIR="${PROJECT_ROOT}/build/Kuzu.xcframework"
if [ -d "${FRAMEWORK_DIR}" ]; then
    echo "删除现有的 XCFramework..."
    rm -rf "${FRAMEWORK_DIR}"
fi

# 清理所有临时目录（防止之前的残留文件）
rm -rf "${PROJECT_ROOT}/build_ios/xcf_temp"
rm -rf "${PROJECT_ROOT}/build_ios_simulator/xcf_temp"  
rm -rf "${PROJECT_ROOT}/build_macos/xcf_temp"
rm -f "${PROJECT_ROOT}/module.modulemap"

# 创建 module.modulemap 文件
echo "创建 module.modulemap 文件..."
cat > "${PROJECT_ROOT}/module.modulemap" << 'EOF'
module Kuzu {
    umbrella header "kuzu.h"
    header "helpers.h"
    export *
    link "kuzu_deps"
}
EOF

# 为每个架构创建干净的临时目录
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
    if [ ! -f "${arch_dir}/module.modulemap" ]; then
        cp "${PROJECT_ROOT}/module.modulemap" "${arch_dir}/"
        echo "已复制 module.modulemap 到: ${arch_dir}"
    else
        echo "module.modulemap 已存在于: ${arch_dir}"
    fi
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