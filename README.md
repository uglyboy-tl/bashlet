# bashlet

一个轻量级 Bash 脚本开发框架：模块化 `import`、参数解析、分级日志、帮助生成、HTTP、配置与终端/标记渲染。

## 特性

- **模块化导入** - `import core/args` 去重加载，`tools/build` 可把依赖内联成单文件脚本
- **参数解析** - 短/长选项、组合选项、子命令、自动帮助
- **分级日志** - `debug/info/warn/success/error`，彩色输出到 stderr
- **终端渲染** - 原语（宽度/对齐/重复）与组合层（section/item/footer/对齐列表）
- **标记渲染** - Markdown 原语 + 报告装配
- **HTTP / SSE** - 基于 curl + jq 的请求封装
- **配置与持久化** - TOML 读取/注册，写盘逻辑独立成可选模块
- **代码极简** - 性能优先，尽量用 Bash 内建替代外部命令

## 架构分层

依赖只能向下，模块即载荷（`tools/build` 会把 import 到的模块内联进产物）：

```
core/   领域装配：args · log · usage · config · config.persist · report   （依赖 std/）
std/    标准库：import · array · map · string · fs · path · system · cache · console · console.layout · console.epipe · ansi · ansi.powerline · markdown
ext/    可选重能力：json · requests · requests.sse · requests.cache · github · select · llm
```

- **终端 vs 标记两条介质分开**：`std/console`（终端）与 `std/markdown`（标记）互不依赖。
- **原语 → 组合 → 领域**：`std/console`（原语）→ `std/console.layout`（section/item/footer）→ `core/usage`。
- **底座必须薄**：`core/log` 依赖 `std/console`，而每个脚本都依赖 `core/log`——所以 `console` 只放原语与通用列表；组合渲染放可选的 `console.layout`。详见 `docs/adr/0001-payload-constraint-module-boundaries.md`。

## 安装

```bash
git clone https://github.com/uglyboy-tl/bashlet.git
cd bashlet
tools/install          # 建立 lib/ 与 test/ 软链，并生成 src/example.sh
```

## 快速开始

新脚本以 `examples/main.sh` 为骨架（`tools/install` 已把它安装为宿主项目的 `src/example.sh`）。构建成单文件后即可运行：

```bash
tools/build src/example.sh -o example
./example --help
```

更多可运行示例：

- `examples/args.sh` - 子命令 CLI（分派、全局选项、帮助）
- `examples/config.sh` - 配置注册 / 加载 / 读写

## 模块列表

### core/

| 模块 | 功能 |
|------|------|
| `args` | 参数/子命令解析、帮助；自动加载 `usage` |
| `log` | 分级日志（stderr，彩色） |
| `usage` | 帮助文本渲染（`args.process --help` 调用） |
| `config` | 配置注册、TOML 读取、内存读写 |
| `config.persist` | 配置写盘（`config.persist.update/save`，可选，含 yq） |
| `report` | Markdown 报告装配与导出 |

### std/

| 模块 | 功能 |
|------|------|
| `import` | `import`、`source` 去重、`.env`（只取调用方脚本所在目录；裸文件名运行时该目录即 CWD） |
| `array` | 索引数组操作 |
| `map` | 关联数组操作 |
| `string` | 字符串/类型/转义/base64 |
| `fs` | 文件/目录、写入、查找替换、解压 |
| `path` | XDG 目录与脚本名 |
| `system` | 命令探测、OS/架构 |
| `cache` | 通用 TTL 缓存：按命名空间 + 键存内容，只做存储与新鲜度判定，策略留给调用方 |
| `console` | 终端原语：写、宽度、对齐、重复、对齐列表 |
| `console.layout` | 终端组合渲染：section、缩进条目、footer |
| `console.epipe` | 非交互输出安全：忽略 SIGPIPE、非 tty 时重定向到日志 |
| `ansi` | 颜色/样式转义码 |
| `ansi.powerline` | powerline/Unicode 字形表（按需 import，底座不背） |
| `markdown` | Markdown 原语（标题、列表、表格、代码…） |

### ext/

| 模块 | 功能 |
|------|------|
| `json` | jq 入口（顶层只定位；跑程序 `json.run`、取值 `json.get`、探活 `json.available`、入口检查 `json.require`） |
| `requests` | HTTP 请求封装（get/post/…、响应解析、download） |
| `requests.sse` | SSE 流式请求（仅少数脚本需要，独立模块） |
| `requests.cache` | HTTP 条件缓存（TTL + ETag/Last-Modified，远端未变时只刷新时间戳） |
| `github` | GitHub API 薄封装（release 查询、资产名匹配、contents、raw URL） |
| `select` | 选择器：fzf / rofi / 原生，按 `SELECT_UI` 分派 |
| `llm` | OpenAI 兼容 chat / 流式 chat |

## 函数速查

> 约定：一切皆 `模块.函数()`；带 `_` 前缀为内部函数。此处只列常用公开函数。

**core/args**：`init` `add_options` `add_subcommand` `process` `parse` `verify` `has` `get` `args` `arg` `opt.arg_index` `show_help` `name` `description` `dispatch`
**core/log**：`debug` `info` `success` `warn` `error` `setLevel`
**core/usage**：`name.set` `description.set` `title` `usage` `section` `section.items` `footer` `show` `version`
**core/config**：`path` `register` `array.register` `loose` `load` `keys` `has` `get` `set` `sections` `array.items` `array.has` `array.get` `array.add` `array.set` `type` `desc`
**core/config.persist**：`update` `save`
**core/report**：`dir.set` `reset` `init` `section` `subsection` `code` `table.begin` `table.add` `table.end` `export`

**std/array**：`len` `contains` `append` `get` `has_duplicates`
**std/map**：`len` `contains` `get`
**std/string**：`trim` `base64.encode` `base64.decode` `escape.regex` `escape.sed` `int.check` `natural.check` `float.check` `is_ascii` `has_ansi`
**std/fs**：`file.exists` `dir.exists` `write` `find` `replace` `insert` `rmline` `cleanup` `mktemp` `file.extract`
**std/path**：`script_name` `config_dir` `data_dir` `state_dir` `cache_dir` `log_dir`
**std/cache**：`dir` `key` `path` `fresh` `put` `get` `clear`
**std/system**：`command.exist` `command.required` `command.result` `gui_supported` `os` `arch`
**std/console**：`stdout` `stderr` `repeat` `align` `indent` `ansi_width` `mixed_width` `display_width`
**std/console.layout**：`section` `footer` `item.title` `item.item` `item.mid` `item.end`
**std/console.epipe**：`init`
**std/ansi**：`enable` `disable` `enable.color` `disable.color` `enable.style` `disable.style` `Color.IsAvailable`
**std/ansi.powerline**：`enable.powerline` `disable.powerline` `Powerline.IsAvailable`（需 import 本模块才有 `POWERLINE_*`；`ansi.disable` 只重置颜色与样式）
**std/markdown**：`escape` `header` `h1`…`h6` `list` `numbered` `todo` `table.header` `table.row` `code` `line` `link` `quote` `front_matter`

**ext/json**：`run` `get` `available` `require`
> `ext/json` 顶层只定位 jq，**首次真正用到时**才探活：缺 jq 时 `json.run`/`json.get` 报错并退出（`--help`/`-v`/`doctor` 仍可用）。调用点跑 jq 程序用 `json.run`（直接 exec、无额外命令替换）；`json.get <json> [filter]` 取一个值；需接住再降级的用 `json.available`（0=可用）。`json.require` 是 fail-loud 出口——包应在自己的入口（主 shell）调一次，否则 `json.run` 在子 shell 里的失败会被静默；`requests.init` 已替 HTTP 路径探过。
**ext/requests**：`init` `available` `curl.available` `timeout` `base_url` `auth` `auth_bearer` `headers.append` `headers.clear` `get` `post` `put` `delete` `patch` `head` `options` `download` `json` `status_code` `exit_code` `headers` `text` `success` `raise_for_status`
> `ext/requests` 必须先调 `requests.init`（定位 curl、设默认头）；不再有懒初始化。缺 curl/jq 时 `exit 1`（硬依赖，调用方不必每处检查）。需要接住再降级的（doctor 的 probe、provider 表）先用 `requests.available`（curl && jq，0=齐）判断，通过了再 init。jq 的探活与定位归 `ext/json`。
**ext/requests.sse**：`sse`
**ext/requests.cache**：`path` `fresh` `fetch` `ensure`
> `requests.cache.ensure URL [ttl秒]`：TTL 内零请求，过期发条件请求；回源失败但有旧缓存时降级使用。内容用 `requests.cache.path URL` 取。
**ext/github**：`init` `api` `release.latest` `release.first` `release.version` `release.pick` `asset.arch_regex` `asset.pattern` `asset.url` `contents.list` `raw.url`
> `github.init` 先调 `requests.init`，参数透传；有 `GITHUB_TOKEN` 时自动加认证头。`asset.pattern` 展开 `{os}`/`{arch}` 占位符供 `asset.url`/`release.pick` 使用。
**ext/select**：`one` `many` `ui` `gui.supported`
**ext/llm**：`init` `api_key` `base_url` `model` `chat` `chat.stream`

## 开发规范

- 函数命名 `模块.函数名()`；全局 `_MODULE_VAR`，局部 `local`。
- 性能优先：优先 Bash 内建/参数展开，避免外部命令与子 shell。
- **不重造轮子**：动手前先查上面的函数速查（如数组用 `array.contains/get`、对齐输出用 `console.align`）。详见 `AGENTS.md`。
- 代码极简：单行函数、紧凑逻辑、尽早返回。

## 构建与测试

```bash
tools/test                 # 运行「当前目录」test/ 下的用例（宿主项目）
tools/test args.bats       # 运行单个文件（相对 test/，不带 test/ 前缀）
tools/test -x requests     # 排除 requests（其用例访问网络，最慢）
tools/test -j 4            # 并行
# 注：test 基于当前工作目录，不是脚本所在目录——在哪个项目根跑，就测哪个项目的 test/

tools/build src/my-script.sh -o my-tool   # 内联依赖成单文件（需 shfmt 才压缩，缺失则跳过）
# 注：默认剥离 .env（产物不读本地 .env，环境变量由真实环境提供）；
#     入口脚本写 `# build:keep-env` 可让该产物保留 .env，
#     保留时 build 把它插在模块内联**之前**（模块顶层读的环境变量才拿得到）。

tools/test payload.bats                   # 载荷棘轮：各模块字节基线（只允许下降/持平）
PAYLOAD_UPDATE=1 tools/test payload.bats  # 增长后刷新基线
```

> `test/payload.bats` 的数值依赖 shfmt 版本；无 shfmt 时不压缩，数值会更大。

## License

MIT
