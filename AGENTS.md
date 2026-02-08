# bashlet - Agent Guidelines

bashlet 是一个 Bash 脚本开发框架，提供基础功能库。

## 项目结构

```
bashlet/
├── lib/core/       # 核心功能（args, log, path）
├── lib/std/        # 标准库（array, map, console, import）
└── test/           # Bats 测试
```

## 基本命令

```bash
# 运行所有测试
test/bats/bin/bats

# 运行单个测试
test/bats/bin/bats test/args.bats
```

## 编码规范

### 命名约定

**函数**: `模块.函数名()`

```bash
args.parse()    array.len()    map.get()
```

**变量**: `_MODULE_VAR` (全局), `local var` (局部)

### 变量作用域

```bash
# 局部变量
local var="value"
local -r readonly_var=$(...)

# 全局数组
declare -ga _GLOBAL_ARRAY=()
declare -gA _GLOBAL_MAP=()

# Nameref (Bash 4.3+) - 传递数组引用（性能优先）
local -n ref="$1"
echo "${#ref[@]}"  # 通过引用访问数组长度
```

### 模块导入

```bash
# 导入模块（自动去重）
import std/array.sh
import core/args.sh
```

**注意**: 所有代码必须定义在函数中（除 import.sh）。

## 极简代码风格

本项目追求性能优先和代码极简，充分利用 Bash 内置特性（除非外部命令效果更好）：

### 1. 单行函数（代码极简）

```bash
args.has() { array.contains _ARGS_OPTS "$1"; }
args.arg() { array.get _ARGS_ARGS "$1"; }
args.count() { array.len _ARGS_ARGS; }
console.stderr() { printf "%s\n" "$*" >&2; }
```

### 2. 紧凑逻辑（性能优先 + 代码极简）

使用 `&&` 和 `||` 避免冗长的 if-else：

```bash
(( $2 >= 0 && $2 < len )) && echo "${ref[$2]}" || return 1
[[ $i ]] && args.arg "$i"
[[ -v "ref[$2]" ]] && echo "${ref[$2]}" || return 1
```

### 3. 省略变量声明（性能优先）

```bash
for arg in "$@"; do ... done        # 不声明 arg
for elem in "${ref[@]}"; do ... done  # 不声明 elem
```

### 4. 字符串操作（性能优先）

使用 Bash 参数展开避免外部命令：

```bash
local c="${arg:1}"  # 去掉第一个字符
for ((i=0; i<${#c}; i++)); do _ARGS_OPTS+=("-${c:i:1}"); done
```

### 5. 正则匹配（性能优先）

使用 `[[ =~ ]]` 避免外部命令：

```bash
[[ $arg =~ ^- ]]                    # 检查是否以 - 开头
[[ $arg =~ ^-[a-zA-Z]{2,}$ ]]       # 检查组合参数
```

### 6. 早期返回（减少嵌套）

快速失败，尽早返回：
```bash
declare -p __loaded_modules &>/dev/null 2>&1 && return 0
[[ -n "${__loaded_modules[$mod]+x}" ]] && return 0
```

### 7. 错误传播

使用 `||` 不中断执行流，传播错误：
```bash
. "$1" || return $?
source "${mod}.sh" 2>/dev/null || source "$mod" 2>/dev/null || return 1
```

## 错误处理

```bash
# 返回非零状态码表示错误
return 1
return $?
```

## 测试

### 测试文件模板

```bash
#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
  _common_setup
  import core/args
  unset _ARGS_OPTS _ARGS_ARGS 2>/dev/null || true
}

teardown() {
  unset _ARGS_OPTS _ARGS_ARGS 2>/dev/null || true
}

@test "测试描述" {
    args.parse -f filename.txt
    result=$(args.get "-f")
    [ "$result" = "filename.txt" ]
}
```

### 测试要求

- 核心功能 100% 覆盖
- 边界条件必须测试
- 错误处理必须测试
- 测试文件命名: `<库名>.bats`

## 代码示例

### 简单函数

```bash
console.stderr() { printf "%s\n" "$*" >&2; }
```

### 数组操作

```bash
array.len() {
  local -n ref="$1"
  echo "${#ref[@]}"
}

array.contains() {
  local -n ref="$1"
  [[ " ${ref[*]} " == *" $2 "* ]]
}

array.get() {
  local -n ref="$1"
  local len=${#ref[@]}
  (( $2 >= 0 && $2 < len )) && echo "${ref[$2]}" || return 1
}
```

### 参数解析

```bash
import std/bash4.sh
import std/array.sh

args.parse() {
  declare -ga _ARGS_OPTS=()
  declare -ga _ARGS_ARGS=()
  declare -gA _ARGS_OPT_ARGS=()

  local end=0 last=""
  for arg in "$@"; do
    if [[ $arg == '--' ]]; then
      end=1
    elif (( !end )) && [[ $arg =~ ^- ]]; then
      _ARGS_OPTS+=("$arg")
      last="$arg"
    else
      _ARGS_ARGS+=("$arg")
      [[ $last ]] && _ARGS_OPT_ARGS["$last"]=$(( ${#_ARGS_ARGS[@]} - 1 )) && last=""
    fi
  done
}

args.has() { array.contains _ARGS_OPTS "$1"; }
args.get() {
  local -r i=$(args.opt_index "$1")
  [[ $i ]] && args.arg "$i"
}
```

## 最佳实践

**核心理念**: 性能优先 + 代码极简（两者兼顾）

1. 一切皆函数，使用 `import` 导入模块
2. 测试驱动：每个函数都有测试，覆盖边界条件
3. 遵循命名规范和代码风格
