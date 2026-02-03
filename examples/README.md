# args 子命令示例

这个示例展示了如何使用 bashlet 的 `args` 模块构建带子命令的 CLI 工具。

## 示例脚本

`args.sh` 演示了一个项目管理工具，支持：

- **全局选项** - 帮助 (-h)、版本 (-V)、详细模式 (-v)
- **子命令** - build、test、deploy，每个都有独立的选项

## 使用方式

### 查看全局帮助和版本

```bash
./args.sh              # 显示全局帮助
./args.sh -h             # 显示全局帮助
./args.sh -V             # 显示版本
```

### 查看子命令帮助

```bash
./args.sh build --help
./args.sh test --help
./args.sh deploy --help
```

### 使用子命令

**参数顺序规则**: 全局选项在子命令之前，子命令选项在子命令之后

```bash
# 构建项目
./args.sh build
./args.sh build -c -v              # 子命令选项：清理并详细输出
./args.sh build --target debug     # 子命令选项：指定构建目标
./args.sh -v build -c              # 全局 verbose + 子命令 build 的 -c 选项

# 运行测试
./args.sh test
./args.sh test -w                  # 监视模式
./args.sh test -f "unit"           # 过滤测试

# 部署应用
./args.sh deploy -e production     # 部署到生产环境
./args.sh deploy -e staging -n     # 模拟部署到测试环境
```

## 关键概念

### 1. 主函数逻辑 - 先子命令后全局选项

```bash
main() {
    # 1. 注册信息和子命令
    args.name.set "项目工具"
    args.add_subcommand "build" "构建项目" "cmd_build"
    args.add_subcommand "test" "运行测试" "cmd_test"

    # 2. 设置全局帮助的 subcommand 占位符
    _ARGS_CURRENT_SUBCOMMAND="<subcommand>"

    # 3. 尝试分发到子命令
    if args.main "$@"; then
        exit 0
    fi

    # 4. 不是子命令，解析全局选项
    args.new_options "global"
    args.add_options "help" "h" "显示帮助信息"
    args.add_options "version" "V" "显示版本信息"
    args.parse "$@"
    args.verify || { args.show_help; exit 1; }

    # 5. 处理全局选项
    args.has "-h" "--help" && { args.show_help; exit 0; }
    args.has "-V" "--version" && { show_version; exit 0; }

    # 6. 无参数或未知情况，显示帮助
    args.show_help
    exit 1
}
```

### 2. 子命令变量控制帮助显示

- `_ARGS_CURRENT_SUBCOMMAND`：当前子命令（用于 Usage 行显示）
- `_ARGS_SUBCOMMANDS`：注册的所有子命令（用于 footer 显示判断）

**全局帮助**（主函数中设置）：
```bash
_ARGS_CURRENT_SUBCOMMAND="<subcommand>"  # Usage 显示占位符
# footer 显示（因为 _ARGS_SUBCOMMANDS 非空）
```

**子命令帮助**（args.main 自动设置）：
```bash
_ARGS_CURRENT_SUBCOMMAND="build"  # Usage 显示实际子命令名
# footer 不显示（因为变量非空）
```

### 2. 子命令处理函数结构

参考 `tools/test.sh` 的标准结构：

```bash
cmd_example() {
    # 1. 设置命令信息
    args.name.set "工具名 - 子命令"
    args.description.set "子命令描述"

    # 2. 创建选项命名空间
    args.new_options "example"
    args.add_options "verbose" "v" "详细输出"
    args.add_options "help" "h" "显示帮助"
    args.add_options "NOTICE" "重要提示信息"
    args.add_options "EXAMPLE" "" "使用示例"

    # 3. 解析、验证、处理帮助
    args.parse "$@"
    args.verify || { args.show_help; return 1; }
    args.has "-h" "--help" && { args.show_help; return 0; }

    # 4. 实现功能
    # ...
}
```

### 3. 注册子命令

```bash
args.add_subcommand "<命令名>" "<描述>" "<处理函数>"
```

### 4. 未知命令处理

通过 `args.verify` 自动处理，未知选项或命令会触发验证失败并显示帮助信息，无需单独处理。

### 2. 子命令处理函数结构

参考 `tools/test.sh` 的标准结构：

```bash
cmd_example() {
    # 1. 设置命令信息
    args.name.set "工具名 - 子命令"
    args.description.set "子命令描述"

    # 2. 创建选项命名空间
    args.new_options "example"
    args.add_options "verbose" "v" "详细输出"
    args.add_options "help" "h" "显示帮助"
    args.add_options "NOTICE" "重要提示信息"
    args.add_options "EXAMPLE" "" "使用示例"

    # 3. 解析、验证、处理帮助
    args.parse "$@"
    args.verify || { args.show_help; return 1; }
    args.has "-h" "--help" && { args.show_help; return 0; }

    # 4. 实现功能
    # ...
}
```

### 3. 全局帮助使用 `args.show_help`

```bash
show_global_help() {
    args.name.set "项目工具"
    args.description.set "项目管理 CLI 工具"
    args.new_options "global"
    args.add_options "verbose" "v" "启用全局详细模式"
    args.add_options "help" "h" "显示帮助信息"
    args.add_options "NOTICE" "可用子命令: build, test, deploy"
    args.add_options "EXAMPLE" "build -c -v" "清理并构建项目"
    args.show_help
}
```

### 4. 注册子命令

```bash
args.add_subcommand "<命令名>" "<描述>" "<处理函数>"
```

## 特点

- **标准主函数结构**: 先尝试子命令分发，失败后再解析全局选项
- **独立选项命名空间**: 每个子命令有自己的选项，使用 `args.show_help` 显示帮助
- **完整的帮助系统**: 支持全局帮助和各子命令独立帮助
- **自动错误处理**: 通过 `args.verify` 自动处理未知命令和选项
- **参考实现**: 子命令处理函数结构参考 `tools/test.sh` 的最佳实践

## 架构

```
主函数逻辑:

1. 注册信息和子命令
   args.name.set / args.add_subcommand
   ↓
2. args.main 分发到子命令
   ├─ 成功 → 子命令处理完毕退出
   └─ 失败 → 继续执行
      ↓
3. 设置全局选项并解析
   args.new_options / args.add_options / args.parse
   args.verify (验证失败自动显示帮助)
      ↓
4. 处理全局选项
   args.has "-h" → 显示帮助
   args.has "-V" → 显示版本
      ↓
5. 其他情况显示帮助

子命令处理函数:

1. args.name.set / args.description.set
2. args.new_options 创建命名空间
3. args.add_options 添加选项、帮助、示例、提示
4. args.parse → args.verify → args.has 处理帮助
5. 实现功能
```
