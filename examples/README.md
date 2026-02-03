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
./args.sh -h           # 显示全局帮助
./args.sh -V           # 显示版本
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
    # 1. 注册子命令
    args.add_subcommand "build" "构建项目" "cmd_build"
    args.add_subcommand "test" "运行测试" "cmd_test"

    # 2. 尝试分发到子命令
    if args.dispatch "$@"; then
        exit 0
    fi

    # 3. 不是子命令，解析全局选项
    args.init "项目管理 CLI 工具"
    args.add_options "help" "h" "显示帮助信息"
    args.add_options "version" "V" "显示版本信息"
    args.parse "$@"
    args.verify || { args.show_help; exit 1; }

    # 4. 处理全局选项
    args.has "-h" "--help" && { args.show_help; exit 0; }
    args.has "-V" "--version" && { show_version; exit 0; }

    # 5. 无参数或未知情况，显示帮助
    args.show_help
    exit 1
}
```

### 2. 子命令处理函数结构

```bash
cmd_example() {
    # 1. 初始化并设置描述
    args.init "子命令描述"

    # 2. 添加选项
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

## 特点

- **标准主函数结构**: 先尝试子命令分发，失败后再解析全局选项
- **简化初始化**: `args.init` 一行完成初始化和描述设置
- **无命名空间**: 选项直接存储在全局数组中，性能更好
- **完整的帮助系统**: 支持全局帮助和各子命令独立帮助
- **自动错误处理**: 通过 `args.verify` 自动处理未知命令和选项

## 架构

```
主函数逻辑:

1. 注册子命令
   args.add_subcommand
   ↓
2. args.dispatch 分发到子命令
   ├─ 成功 → 子命令处理完毕退出
   └─ 失败 → 继续执行
      ↓
3. 设置全局选项并解析
   args.init / args.add_options / args.parse
   args.verify (验证失败自动显示帮助)
      ↓
4. 处理全局选项
   args.has "-h" → 显示帮助
   args.has "-V" → 显示版本
      ↓
5. 其他情况显示帮助

子命令处理函数:

1. args.init "描述"              # 初始化 + 设置描述
2. args.add_options 添加选项    # 添加选项、帮助、示例、提示
3. args.parse → args.verify → args.has 处理帮助
4. 实现功能
```

## API 变更说明

从旧版本迁移的注意事项：

| 旧 API | 新 API | 说明 |
|--------|--------|------|
| `args.new_options "name"` | `args.init ["描述"]` | 无需命名空间参数，支持可选描述 |
| `args.name.set "xxx"` | 无需调用 | 标题自动生成 |
| `args.description.set "xxx"` | `args.init "xxx"` | 合并到 init 参数 |
| `args.main` | `args.dispatch` | 函数重命名 |
