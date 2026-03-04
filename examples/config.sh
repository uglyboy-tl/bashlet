#!/usr/bin/env bash
#
# config 模块使用示例
# 通过代码展示配置注册、加载、数组配置和保存功能
#

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$PROJECT_ROOT/lib/std/import.sh"

import core/config

main() {
  # 清理临时文件
  rm -f config-example.toml config-saved.toml 2> /dev/null || true

  # 1. 注册配置项
  config.register "app.name" "myapp" "string" "应用名称"
  config.register "app.version" "1.0.0" "string" "应用版本"

  # 注册数组配置字段
  config.array.register "servers" "host" "" "string" "服务器地址"
  config.array.register "servers" "port" "22" "string" "SSH端口"

  # 2. 创建并加载配置文件
  cat > config-example.toml << 'EOF'
[app]
name = "示例应用"
version = "2.0.0"

[servers.web]
host = "192.168.1.100"
port = "80"

[servers.db]
host = "192.168.1.101"
port = "3306"
EOF

  config.load config-example.toml

  # 3. 使用配置 - 获取应用信息
  app_name=$(config.get app.name)
  app_version=$(config.get app.version)

  # 4. 使用配置 - 处理服务器列表
  server_items=$(config.array.items servers)
  for server in $server_items; do
    host=$(config.array.get servers "$server" host)
    port=$(config.array.get servers "$server" port)
    # 在实际应用中，这里会使用这些配置进行连接等操作
  done

  # 5. 修改配置
  config.set app.version "2.1.0"

  # 添加新服务器
  config.array.set servers "cache" "host" "192.168.1.102"
  config.array.set servers "cache" "port" "6379"

  # 6. 保存配置（使用过滤）
  filter_keys=("app.name" "app.version")
  declare -A filter_arrays=([servers]="host port")

  config.save config-saved.toml filter_keys filter_arrays

  # 7. 清理
  rm -f config-example.toml config-saved.toml 2> /dev/null || true
}

main "$@"
