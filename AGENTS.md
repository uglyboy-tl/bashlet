# bashlet - Agent Guidelines

bashlet 是一个 Bash 脚本开发框架，提供基础功能库。

## 架构与载荷约束

依赖只能向下：`core/ → std/`；`ext/` 为可选重能力。`tools/build` 会把 import 到的模块**内联进产物**，所以**模块即载荷**——加进某个模块的代码，所有 import 它的脚本都要背。

- **底座必须薄**：每个脚本都 import `core/args`，而 args import `core/usage`，`core/log` import `std/console`。所以 `usage`/`log` 依赖的任何东西，全员都会背。别把可选重能力塞进这些模块。
- **终端 vs 标记分开**：`std/console` 与 `std/markdown` 互不依赖。
- **原语 → 组合 → 领域**：`std/console`（原语/对齐列表）→ `std/console.layout`（section/item/footer，可选）→ `core/usage`。
- 判断某能力该不该独立成模块：**语意性 × 反冗余**权衡。详见 `docs/adr/0001-payload-constraint-module-boundaries.md`。

加新模块后，用 `tools/build` 构建下游脚本，确认**不相关的脚本体积没有变大**。`test/payload.bats` 用「只 import 该模块」的最小消费者记录各模块字节基线（棘轮：只允许下降/持平）：

```bash
tools/test payload.bats                   # 校验
PAYLOAD_UPDATE=1 tools/test payload.bats  # 增长后刷新基线
```

## 复用优先（不要重造轮子）

动手前先查 `README.md` 的「函数速查」。常见意图对应的既有函数：

| 想要 | 用 |
|------|-----|
| 判断数组/键是否存在 | `array.contains ARR V`、`map.contains MAP K` |
| 取数组元素/长度 | `array.get ARR I`、`array.len ARR`、`map.len MAP`（纯 `${#ref[@]}` 更快时可直接用） |
| 去空白 / 类型检查 / 转义 | `string.trim`、`string.int.check`/`natural.check`/`float.check`、`string.escape.regex`/`escape.sed` |
| 文件/目录、写入、查找替换、解压 | `fs.file.exists`、`fs.dir.exists`、`fs.write`、`fs.find`/`replace`/`insert`、`fs.file.extract` |
| XDG 目录、脚本名 | `path.config_dir`/`data_dir`/`state_dir`/`cache_dir` |
| 外部命令探测、OS/架构 | `system.command.exist`/`required`、`system.os`/`arch` |
| 图形会话探测 | `system.gui_supported` |
| 终端写/宽度/对齐/重复 | `console.stdout`/`stderr`、`console.display_width`、`console.align`、`console.repeat`、`console.indent` |
| 终端 section / 缩进条目 / footer | `console.layout.*` |
| Markdown | `markdown.*` |
| HTTP / 下载 / SSE | `ext/requests`（`requests.download` 在同一模块；`requests.sse` 在 `ext/requests.sse`） |

注意：性能优先——`${#arr[@]}`、`[[ -v map[k] ]]` 这类纯内建比调用 `array.len`/`map.contains`（走子 shell/echo）更快，允许内联。

## 项目结构

```
bashlet/
├── lib/core/      # 领域装配：args log usage config config.persist report
├── lib/std/       # 标准库：import array map string fs path system cache console console.layout console.epipe ansi ansi.powerline markdown
├── lib/ext/       # 可选：requests requests.sse requests.cache github select llm
├── tools/         # install / build / test
├── test/          # Bats 测试（每个模块一个 <name>.bats）
└── docs/adr/      # 架构决策记录
```

## 基本命令

```bash
tools/test                 # 运行当前目录 test/ 下的测试（基于 CWD，不是脚本位置）
tools/test args.bats       # 运行单个测试文件（相对 test/，不要带 test/ 前缀）
tools/test -x requests     # 排除 requests（访问网络，最慢；改非 requests 模块时用它）
tools/test -j 4            # 并行运行
tools/build src/x.sh -o x  # 内联依赖成单文件（shfmt 可选；默认剥离 .env，`# build:keep-env` 可保留）
                           # import 解析顺序：入口目录的 lib/ 优先（脚本私有模块），再回退框架 lib/
                           # 所以脚本可以自带 lib/ 放私有模块，与框架模块同名不冲突
tools/install              # 在宿主仓库建立 lib/ 与 test/ 软链，生成 src/example.sh
```

## 编码规范

### 命名约定

**函数**: `模块.函数名()`。**函数前缀必须等于文件名/模块名**（拆分模块时一并改名）。

```bash
args.process()    array.len()    map.get()    console.align()
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
import std/array
import core/args
```

**注意**: 除 `std/import.sh` 外，所有代码必须定义在函数中（顶层只能有 `import`、变量声明与常量赋值）。

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

`basename`/`dirname` 用展开替代：`${var##*/}`、`${var%/*}`。重复字符用 `printf -v` + `${s// /x}`，不要 `printf | tr`。

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

库函数用 `return` 传播错误，**不要调用 `exit`**（`system.command.required` 是已知例外）。

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
    args.process -f filename.txt
    result=$(args.get "-f")
    [ "$result" = "filename.txt" ]
}
```

### 测试要求

- 核心功能 100% 覆盖
- 边界条件必须测试
- 错误处理必须测试
- 测试文件命名: `<库名>.bats`；拆分出的模块单独成文件（如 `console.layout.bats`）
- 改动某模块行为时**同步更新其测试**，不要留下固化旧 bug 的断言
- 断言不要依赖 OS 错误文案（locale 相关），断言退出码/状态
