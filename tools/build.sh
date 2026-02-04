#!/usr/bin/env bash

# Bin Updater Build Script - 将所有模块合并成单一文件

set -euo pipefail

LC_COLLATE=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/src/std/import.sh"

import core/args

# 在这里定义脚本名称
SCRIPT_NAME="BinUp"

# 处理 lib 文件：移除 shebang、set、注释，并删除空白行
process_sub_file() {
    local file="$1"
    local content=""
    local line

    # 逐行读取文件
    while IFS= read -r line || [ -n "$line" ]; do
        # 删除行尾空白
        line="${line%"${line##*[![:space:]]}"}"

        # 如果不是空白行，则处理注释
        if [[ -n "$line" ]]; then
            # 只删除以空格或行首开始的 # 注释
            # 这样可以保护 ${var#pattern} 和字符串中的 #
            if [[ "$line" =~ ^[[:space:]]*# ]]; then
                # 整行都是注释，跳过
                continue
            elif [[ "$line" =~ [[:space:]]# ]]; then
                # 行中有注释，删除 # 及其后面的内容
                line="${line%%#*}"
                # 删除可能产生的行尾空白
                line="${line%"${line##*[![:space:]]}"}"
            fi

            # 如果处理后还有内容，则添加
            if [[ -n "$line" ]]; then
                content="${content}${line}"$'\n'
            fi
        fi
    done < "$file"

    # 移除顶部的 shebang（处理多行情况）
    content="${content#\#!/usr/bin/env bash}"
    content="${content#\#!/bin/bash}"

    # 移除顶部的 set 行
    content="${content#set -euo pipefall}"
    content="${content#set -euo pipefail}"

    # 移除后续的 set 行
    content=$(echo "$content" | grep -Ev '^set -euo pipefail$')

    # 把所有 source 语句中的文件名改成不存在的路径
    content=$(echo "$content" | sed 's|source "\$SCRIPT_DIR/|source "_NONE_/|g')
    # 同时替换 if 条件中的路径
    content=$(echo "$content" | sed 's|\[\[ -f "\$SCRIPT_DIR/|\[\[ -f "_NONE_/|g')

    echo "$content"
}

build() {
    log.info "开始构建..."

    > "$OUTPUT_FILE"

    {
        echo '#!/usr/bin/env bash'
        echo 'set -euo pipefail'
        echo ''
        echo "SCRIPT_NAME=\"$SCRIPT_NAME\""
        echo 'VERSION="0.1.0"'
        echo ''
    } >> "$OUTPUT_FILE"

    # 合并所有 lib 文件
    for file in lib/*.sh main.sh; do
        log.info "合并: $file"
        process_sub_file "$SCRIPT_DIR/$file" >> "$OUTPUT_FILE"
    done

    chmod +x "$OUTPUT_FILE"
    local size
    size=$(du -h "$OUTPUT_FILE" | cut -f1)
    log.success "完成! 大小: $size"
    log.info ""
    log.info "用法: $OUTPUT_FILE <command>"
    log.info "  list/update/upgrade/install"
}

main() {
    args.init "Shell 脚本打包工具"
	args.add_options "output" "o" "输出文件" "STRING"
    args.process "$@"
    build
}

# 入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
