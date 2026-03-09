# bashlet

一个轻量级 Bash 脚本开发框架，提供模块化导入、参数解析、日志输出等基础功能。

## 特性

- **模块化导入** - 类似其他语言的 `import` 机制
- **参数解析** - 完整的命令行参数解析，支持短选项、长选项、子命令
- **日志输出** - 带颜色的分级日志（debug/info/warn/error/success）
- **帮助生成** - 自动生成格式化的帮助信息
- **代码极简** - 追求性能优先和代码极简风格

## 安装

```bash
git clone https://github.com/yourusername/bashlet.git
cd bashlet
```

## 快速开始

```bash
#!/usr/bin/env bash

# 导入框架
source "path/to/bashlet/lib/std/import.sh"
import core/args
import core/log

# 初始化参数解析
args.init "示例脚本"
args.add_options "file" "f" "输入文件" "FILE"
args.add_options "verbose" "v" "详细输出"
args.add_options "help" "h" "显示帮助"

# 解析参数
args.parse "$@"
args.verify || { args.show_help; exit 1; }

# 检查选项
if args.has "-h" "--help"; then
    args.show_help
    exit 0
fi

# 获取选项值
if file=$(args.get "-f" "--file"); then
    log.info "输入文件: $file"
fi

args.has "-v" "--verbose" && log.info "详细模式已启用"
```

## 模块列表

### 核心模块 (core/)

| 模块 | 功能 |
|------|------|
| `args` | 参数解析、选项管理、帮助生成 |
| `log` | 分级日志输出（debug/info/warn/error/success） |
| `usage` | 帮助信息格式化显示 |

### 标准库 (std/)

| 模块 | 功能 |
|------|------|
| `import` | 模块导入系统 |
| `array` | 数组操作（contains/get/len 等） |
| `map` | 关联数组操作 |
| `console` | 控制台输出工具 |
| `ansi` | ANSI 颜色代码 |

## API 参考

### args 模块

#### args.init [描述]

初始化选项系统。可选的描述参数会设置 `_SCRIPT_DESC`。

```bash
args.init "脚本描述"
```

#### args.add_options 名称 短选项 描述 [类型]

添加命令行选项。

```bash
# 无参数选项
args.add_options "verbose" "v" "详细输出"

# 带参数选项
args.add_options "file" "f" "输入文件" "FILE"

# 添加 ARG 参数说明
args.add_options "ARG" "filename" "输入文件名"

# 添加示例
args.add_options "EXAMPLE" "-f input.txt" "处理输入文件"

# 添加注意事项
args.add_options "NOTICE" "文件必须是 UTF-8 编码"
```

#### args.parse 参数...

解析命令行参数。

```bash
args.parse "$@"
```

#### args.has 选项...

检查选项是否存在（支持多个别名）。

```bash
args.has "-v" "--verbose" && echo "详细模式"
```

#### args.get 选项...

获取选项的参数值。

```bash
if value=$(args.get "-f" "--file"); then
    echo "文件: $value"
fi
```

#### args.verify

验证所有选项是否合法。

```bash
args.verify || { args.show_help; exit 1; }
```

#### args.dispatch 子命令

分派到已注册的子命令。

```bash
args.add_subcommand "build" "构建项目" "cmd_build"
args.dispatch "$@" || echo "未知子命令"
```

### log 模块

```bash
log.debug "调试信息"
log.info "普通信息"
log.warn "警告信息"
log.error "错误信息"
log.success "成功信息"
```

## 开发规范

- 函数命名：`模块.函数名()`
- 全局变量：`$_MODULE_VAR`
- 局部变量：`local var`
- 性能优先：使用 Bash 内置特性，避免外部命令
- 代码极简：单行函数、紧凑逻辑

## 运行测试

```bash
# 运行所有测试
./test/bats/bin/bats test/

# 运行单个测试文件
./test/bats/bin/bats test/args.bats

# 使用测试工具
./tools/test.sh
```

## 示例

查看 `examples/` 目录获取更多示例：

- `args.sh` - 完整的子命令 CLI 工具示例
- `config.sh` - 完整的配置文件使用示例
- `main.sh` - 一般脚本示例

## License

MIT
