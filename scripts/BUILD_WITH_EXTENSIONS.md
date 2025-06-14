# Kuzu 扩展构建指南

## 📋 概述

本指南说明如何为 Kuzu 数据库构建包含扩展的 iOS/macOS XCFramework。

## 🚀 快速开始

### 本地构建

```bash
# 1. 配置扩展（编辑 extension/extension_config.cmake）
# 2. 直接运行构建脚本
./scripts/build-ios-sim-mac-xcframework_local.sh
```

### CI/CD 构建

```bash
# 设置工具链路径环境变量
export CI_TOOLCHAIN_PATH="/path/to/ios.toolchain.cmake"
./scripts/build-ios-sim-mac-xcframework.sh
```

## 🔧 CI/CD 配置

### GitHub Actions 示例

```yaml
name: Build iOS XCFramework
on: [push, pull_request]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: 设置工具链
        run: |
          # 下载或设置iOS工具链
          curl -L https://github.com/leetal/ios-cmake/raw/master/ios.toolchain.cmake \
            -o /tmp/ios.toolchain.cmake
          export CI_TOOLCHAIN_PATH="/tmp/ios.toolchain.cmake"

      - name: 构建XCFramework
        env:
          CI_TOOLCHAIN_PATH: "/tmp/ios.toolchain.cmake"
        run: ./scripts/build-ios-sim-mac-xcframework.sh
```

### Jenkins 示例

```groovy
pipeline {
    agent { label 'macos' }
    environment {
        CI_TOOLCHAIN_PATH = '/var/jenkins/ios.toolchain.cmake'
    }
    stages {
        stage('Build') {
            steps {
                sh './scripts/build-ios-sim-mac-xcframework.sh'
            }
        }
    }
}
```

## 🔄 统一脚本特性

### 环境自动检测

脚本会按以下优先级查找工具链：

1. `CI_TOOLCHAIN_PATH` 环境变量 (CI/CD 环境)
2. `/Users/gl/toolchains/ios.toolchain.cmake` (本地环境)
3. `${PROJECT_ROOT}/ios.toolchain.cmake` (项目根目录)

### 扩展管理

- ✅ 自动检测启用的扩展
- ✅ 动态添加扩展库到构建
- ✅ 平台隔离构建，避免混合
- ✅ 构建前自动清理缓存

### 平台支持

- 📱 iOS 真机 (arm64)
- 📱 iOS 模拟器 (arm64)
- 💻 macOS (arm64)

## 📦 可用扩展

### 无外部依赖 ✅

- `fts` - 全文搜索
- `json` - JSON 处理
- `vector` - 向量搜索
- `algo` - 图算法
- `neo4j` - Neo4j 导入

### 需要外部依赖 ⚠️

- `duckdb` - DuckDB 集成 (需要 DuckDB)
- `postgres` - PostgreSQL 连接器 (需要 DuckDB)
- `sqlite` - SQLite 支持 (需要 DuckDB)
- `delta` - Delta Lake 支持 (需要 DuckDB)
- `iceberg` - Apache Iceberg (需要 DuckDB)
- `unity_catalog` - Unity Catalog (需要 DuckDB)
- `httpfs` - HTTP 文件系统 (需要 OpenSSL)

## ⚙️ 扩展配置

编辑 `extension/extension_config.cmake`:

```cmake
# 启用扩展
add_static_link_extension(fts)       # 全文搜索
add_static_link_extension(json)      # JSON处理
add_static_link_extension(vector)    # 向量搜索
add_static_link_extension(algo)      # 图算法
add_static_link_extension(neo4j)     # Neo4j导入

# 禁用需要外部依赖的扩展
# add_static_link_extension(duckdb)     # 需要DuckDB
# add_static_link_extension(httpfs)     # 需要OpenSSL
```

## 🛠️ 故障排除

### 常见问题

1. **工具链未找到**

   ```bash
   ❌ 错误：未找到iOS工具链文件
   ```

   解决：设置 `CI_TOOLCHAIN_PATH` 环境变量

2. **平台混合错误**

   ```bash
   ld: building for 'macOS', but linking in object file built for 'iOS-simulator'
   ```

   解决：脚本会自动清理扩展构建目录

3. **扩展库缺失**
   ```bash
   ⚠️ 未找到扩展库: libkuzu_xxx_static_extension.a
   ```
   解决：检查扩展配置或依赖安装

### 调试模式

```bash
# 启用详细输出
VERBOSE=1 ./scripts/build-ios-sim-mac-xcframework.sh
```

## 📊 构建输出

成功构建后会生成：

- `build/Kuzu.xcframework` - 跨平台框架
- 支持 iOS 真机、iOS 模拟器、macOS
- 包含所有启用的扩展

## 🔍 验证构建

使用验证脚本检查结果：

```bash
./scripts/verify_extensions_simple.sh
```

验证内容：

- ✅ XCFramework 结构
- ✅ 平台支持
- ✅ 扩展符号存在
- ✅ 架构正确性
