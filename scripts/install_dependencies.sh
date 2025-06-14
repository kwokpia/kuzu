#!/bin/bash

# Kuzu扩展依赖安装脚本
# 该脚本将安装构建所有扩展所需的外部依赖

set -e

echo "🔧 安装Kuzu扩展依赖..."

# 检查是否安装了Homebrew
if ! command -v brew &> /dev/null; then
    echo "❌ 需要安装Homebrew才能继续"
    echo "请访问 https://brew.sh 安装Homebrew"
    exit 1
fi

echo "✅ 检测到Homebrew"

# # 安装DuckDB
# echo -e "\n📦 安装DuckDB..."
# if brew list duckdb &>/dev/null; then
#     echo "✅ DuckDB已安装"
# else
#     echo "正在安装DuckDB..."
#     brew install duckdb
#     echo "✅ DuckDB安装完成"
# fi

# # 检查DuckDB版本
# echo "DuckDB版本: $(duckdb --version)"

# 安装OpenSSL
echo -e "\n🔐 安装OpenSSL..."
if brew list openssl &>/dev/null; then
    echo "✅ OpenSSL已安装"
else
    echo "正在安装OpenSSL..."
    brew install openssl
    echo "✅ OpenSSL安装完成"
fi

# 设置环境变量
echo -e "\n⚙️  配置环境变量..."
OPENSSL_ROOT_DIR=$(brew --prefix openssl)
echo "OpenSSL路径: $OPENSSL_ROOT_DIR"

# 检查DuckDB的CMake配置
# echo -e "\n🔍 检查DuckDB CMake配置..."
# DUCKDB_PREFIX=$(brew --prefix duckdb)
# echo "DuckDB前缀: $DUCKDB_PREFIX"

# # 查找DuckDB配置文件
# CMAKE_CONFIG_PATHS=(
#     "$DUCKDB_PREFIX/lib/cmake/DuckDB"
#     "$DUCKDB_PREFIX/lib/cmake/duckdb" 
#     "/usr/local/lib/cmake/DuckDB"
#     "/usr/local/lib/cmake/duckdb"
#     "/opt/homebrew/lib/cmake/DuckDB"
#     "/opt/homebrew/lib/cmake/duckdb"
# )

# DUCKDB_CONFIG_FOUND=false
# for path in "${CMAKE_CONFIG_PATHS[@]}"; do
#     if [ -d "$path" ]; then
#         echo "✅ 找到DuckDB CMake配置: $path"
#         DUCKDB_CONFIG_FOUND=true
#         export DuckDB_DIR="$path"
#         break
#     fi
# done

# if [ "$DUCKDB_CONFIG_FOUND" = false ]; then
#     echo "⚠️  警告: 未找到DuckDB CMake配置文件"
#     echo "尝试手动设置CMAKE_PREFIX_PATH..."
# fi

echo -e "\n📝 建议的环境变量设置:"
echo "export OPENSSL_ROOT_DIR=\"$OPENSSL_ROOT_DIR\""
# echo "export CMAKE_PREFIX_PATH=\"$DUCKDB_PREFIX:\$CMAKE_PREFIX_PATH\""
# if [ "$DUCKDB_CONFIG_FOUND" = true ]; then
#     echo "export DuckDB_DIR=\"$DuckDB_DIR\""
fi

echo -e "\n🎯 下一步操作:"
echo "1. 运行以下命令设置环境变量:"
echo "   export OPENSSL_ROOT_DIR=\"$OPENSSL_ROOT_DIR\""
# echo "   export CMAKE_PREFIX_PATH=\"$DUCKDB_PREFIX:\$CMAKE_PREFIX_PATH\""
# if [ "$DUCKDB_CONFIG_FOUND" = true ]; then
#     echo "   export DuckDB_DIR=\"$DuckDB_DIR\""
# fi
echo ""
echo "2. 修改 extension/extension_config.cmake 启用所有扩展"
echo "3. 运行构建脚本:"
echo "   ./scripts/build-ios-sim-mac-xcframework_local.sh"

echo -e "\n✅ 依赖安装完成!" 