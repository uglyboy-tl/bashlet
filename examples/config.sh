#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../src"

source "${LIB_DIR}/std/import.sh"

import core/config
import core/log

log.setLevel DEBUG

echo "=== 示例 1: 基本使用 ==="

config.register "download_dir" "string" "/tmp/downloads" "下载目录"
config.register "proxy_prefix" "string" "" "代理服务器前缀"
config.register "log_level" "string" "info" "日志级别"
config.register "api_token" "string" "" "API 访问令牌"

echo "已注册的配置项:"
config.keys

cat > /tmp/example_config.toml << 'EOF'
download_dir = "/home/user/Downloads"
proxy_prefix = "https://proxy.example.com/"
log_level = "debug"
api_token = "secret_token_12345"
EOF

echo ""
echo "加载配置文件..."
config.load /tmp/example_config.toml

echo ""
config.debug

echo ""
echo "获取配置值:"
echo "  下载目录: $(config.get download_dir)"
echo "  代理前缀: $(config.get proxy_prefix)"
echo "  日志级别: $(config.get log_level)"

echo ""
echo "验证配置..."
if config.verify; then
	echo "  验证通过"
else
	echo "  验证失败"
fi

echo ""
echo "=== 示例 2: 默认值 ==="

config.reset

config.register "timeout" "int" "30"
config.register "retries" "int" "3"

config.load /dev/null 2>/dev/null || true

echo "使用默认值:"
echo "  超时时间: $(config.get timeout)"
echo "  重试次数: $(config.get retries)"

echo ""
echo "运行时设置新值:"
config.set timeout 60
echo "  新的超时时间: $(config.get timeout)"

echo ""
echo "=== 示例 3: 白名单过滤 ==="

config.reset

config.register "name" "string" ""
config.register "version" "string" "1.0.0"

cat > /tmp/partial_config.toml << 'EOF'
name = "myapp"
version = "2.0.0"
ignored_key = "this will be ignored"
another_unused = "also ignored"
EOF

config.load /tmp/partial_config.toml

echo "加载后:"
config.debug

echo ""
echo "检查忽略的键是否存在:"
config.has name && echo "  name: 存在"
config.has ignored_key && echo "  ignored_key: 存在" || echo "  ignored_key: 不存在"

rm -f /tmp/example_config.toml /tmp/partial_config.toml

echo ""
echo "=== 示例结束 ==="
