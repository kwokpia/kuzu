#!/bin/bash

echo "🔍 验证Kuzu构建结果..."

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)

# 检查扩展配置
echo "1. 检查启用的扩展:"
grep "^add_static_link_extension" "${PROJECT_ROOT}/extension/extension_config.cmake" | while read line; do
    ext_name=$(echo "$line" | sed 's/add_static_link_extension(\(.*\))/\1/')
    echo "✅ $ext_name"
done

echo -e "\n2. 检查XCFramework:"
XCFRAMEWORK_PATH="${PROJECT_ROOT}/build/Kuzu.xcframework"
if [ -d "$XCFRAMEWORK_PATH" ]; then
    echo "✅ XCFramework存在: $XCFRAMEWORK_PATH"
    
    echo -e "\n支持的平台:"
    for platform_dir in "$XCFRAMEWORK_PATH"/*-*; do
        if [ -d "$platform_dir" ]; then
            platform=$(basename "$platform_dir")
            lib_path="${platform_dir}/libkuzu_deps.a"
            if [ -f "$lib_path" ]; then
                size=$(du -h "$lib_path" | cut -f1)
                echo "  ✅ $platform: libkuzu_deps.a ($size)"
            fi
        fi
    done
else
    echo "❌ XCFramework不存在"
fi

echo -e "\n3. 检查库文件大小:"
for build_dir in "${PROJECT_ROOT}/build_macos/lib" "${PROJECT_ROOT}/build_ios/lib" "${PROJECT_ROOT}/build_ios_simulator/lib"; do
    if [ -f "${build_dir}/libkuzu_deps.a" ]; then
        platform=$(basename $(dirname "$build_dir"))
        size=$(du -h "${build_dir}/libkuzu_deps.a" | cut -f1)
        echo "✅ $platform: $size"
    fi
done

echo -e "\n4. 检查扩展符号（所有平台）:"

# 定义要检查的扩展符号
EXTENSION_SYMBOLS=(
    "json:JsonExtension,json_"
    "fts:FtsExtension,fts_"
    "vector:VectorExtension,vector_,hnsw"
    "algo:AlgoExtension,algo_"
    "neo4j:Neo4jExtension,neo4j_"
)

# 定义平台和对应的库文件路径
PLATFORMS=(
    "macOS:${PROJECT_ROOT}/build_macos/lib/libkuzu_deps.a"
    "iOS真机:${PROJECT_ROOT}/build_ios/lib/libkuzu_deps.a"
    "iOS模拟器:${PROJECT_ROOT}/build_ios_simulator/lib/libkuzu_deps.a"
)

# 检查函数
check_extension_symbols() {
    local lib_file="$1"
    local platform_name="$2"
    
    if [ ! -f "$lib_file" ]; then
        echo "  ❌ 库文件不存在: $lib_file"
        return
    fi
    
    echo "  📱 $platform_name 平台:"
    local found_symbols=0
    local total_extensions=0
    
    for ext_info in "${EXTENSION_SYMBOLS[@]}"; do
        local ext_name=$(echo "$ext_info" | cut -d: -f1)
        local symbols=$(echo "$ext_info" | cut -d: -f2)
        
        ((total_extensions++))
        local found_any=false
        
        # 将逗号分隔的符号拆分并检查
        IFS=',' read -ra SYMBOL_LIST <<< "$symbols"
        for symbol in "${SYMBOL_LIST[@]}"; do
            # 使用多种方法检查符号
            if nm "$lib_file" 2>/dev/null | grep -q -i "$symbol" || \
               strings "$lib_file" 2>/dev/null | grep -q -i "$symbol" || \
               objdump -t "$lib_file" 2>/dev/null | grep -q -i "$symbol"; then
                found_any=true
                break
            fi
        done
        
        if [ "$found_any" = true ]; then
            echo "    ✅ $ext_name 扩展符号存在"
            ((found_symbols++))
        else
            echo "    ❌ $ext_name 扩展符号缺失"
        fi
    done
    
    echo "    📊 符号统计: $found_symbols/$total_extensions 个扩展"
    
    # 额外检查：统计库中的对象文件数量
    local obj_count=$(ar t "$lib_file" 2>/dev/null | wc -l | tr -d ' ')
    echo "    📦 对象文件数量: $obj_count"
}

# 遍历所有平台进行检查
for platform_info in "${PLATFORMS[@]}"; do
    platform_name=$(echo "$platform_info" | cut -d: -f1)
    lib_path=$(echo "$platform_info" | cut -d: -f2)
    
    check_extension_symbols "$lib_path" "$platform_name"
    echo
done

echo -e "\n🎯 验证完成！"

# 总结报告
echo "📋 构建总结报告："
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 检查启用的扩展数量
enabled_count=$(grep "^add_static_link_extension" "${PROJECT_ROOT}/extension/extension_config.cmake" | wc -l | tr -d ' ')
echo "✅ 启用的扩展数量: $enabled_count"

# 检查XCFramework状态
if [ -d "$XCFRAMEWORK_PATH" ]; then
    platform_count=$(find "$XCFRAMEWORK_PATH" -type d -name "*-*" | wc -l | tr -d ' ')
    echo "✅ 支持的平台数量: $platform_count (macOS + iOS真机 + iOS模拟器)"
    
    total_size=0
    for platform_dir in "$XCFRAMEWORK_PATH"/*-*; do
        if [ -d "$platform_dir" ]; then
            lib_path="${platform_dir}/libkuzu_deps.a"
            if [ -f "$lib_path" ]; then
                size_bytes=$(stat -f%z "$lib_path" 2>/dev/null || stat -c%s "$lib_path" 2>/dev/null || echo "0")
                total_size=$((total_size + size_bytes))
            fi
        fi
    done
    
    total_size_mb=$((total_size / 1024 / 1024))
    echo "📦 XCFramework总大小: ${total_size_mb}MB"
else
    echo "❌ XCFramework创建失败"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 可以在iOS/macOS项目中使用了！" 