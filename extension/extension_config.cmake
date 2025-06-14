# ===================================================================
# 扩展配置文件 - 静态链接扩展
# ===================================================================
# 
# 注意：某些扩展需要外部系统依赖：
# - duckdb, postgres, sqlite, delta, iceberg, unity_catalog: 需要 DuckDB 库
# - httpfs: 需要 OpenSSL 库
# 
# 如果缺少依赖，请先安装或者只启用无外部依赖的扩展
# ===================================================================

# 无外部依赖的扩展（推荐启用）
add_static_link_extension(fts)      # 全文搜索 - 使用内置依赖
add_static_link_extension(json)     # JSON处理 - 使用内置yyjson
add_static_link_extension(vector)   # 向量搜索 - 使用内置simsimd
add_static_link_extension(algo)     # 图算法 - 纯内置实现
add_static_link_extension(neo4j)    # Neo4j导入 - 无外部依赖

# 需要外部DuckDB依赖的扩展（如果有DuckDB可启用）
#add_static_link_extension(delta)        # Delta Lake - 需要DuckDB
#add_static_link_extension(duckdb)       # DuckDB存储 - 需要DuckDB
#add_static_link_extension(iceberg)      # Iceberg - 需要DuckDB
#add_static_link_extension(postgres)     # PostgreSQL - 需要DuckDB
#add_static_link_extension(sqlite)       # SQLite - 需要DuckDB
#add_static_link_extension(unity_catalog) # Unity Catalog - 需要DuckDB

# 需要OpenSSL依赖的扩展
# add_static_link_extension(httpfs)       # HTTP文件系统 - 需要OpenSSL

if(${BUILD_WASM})
    message(STATUS "Building for WASM, extension static linking is enabled by default")
    add_static_link_extension(fts)
    add_static_link_extension(json)
    add_static_link_extension(vector)
    add_static_link_extension(algo)
endif()

if(ANDROID_ABI)
    message(STATUS "Building for Android, extension static linking is enabled by default")
    add_static_link_extension(fts)
    add_static_link_extension(json)
    add_static_link_extension(vector)
    add_static_link_extension(algo)
endif()

if(${BUILD_SWIFT})
    message(STATUS "Building for Swift binding, extension static linking is enabled by default")
    add_static_link_extension(fts)
    add_static_link_extension(json)
    add_static_link_extension(vector)
    add_static_link_extension(algo)
endif()

# Enable all extensions for iOS builds
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    message(STATUS "Building for iOS, all available extensions are statically linked")
endif()
