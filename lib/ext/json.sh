#!/usr/bin/env bash
# shellcheck disable=SC2016

import core/log
import std/system

# jq 的唯一入口。import 本模块即声明「依赖 jq」，所以探活在顶层做，不设 init、不做懒初始化：
# 无状态模块再让调用方多写一行 `json.init`，只是把同一件事声明两遍，且忘了写就静默不探活。
#
# 不进 std/：jq 与 curl / fzf 同属 ext 的「可选重能力」（std/ 只放 coreutils 类）。
# 硬依赖用 system.command.required（缺了 exit 1），可选依赖（如 ext/select 的 fzf）才走回退。

declare -g _JSON_BIN

system.command.required jq
_JSON_BIN="$(command -v jq)"

# jq 的调用点用 json.run -c '<program>'；不要直接读 _JSON_BIN（私有变量不跨模块读）
json.bin() { printf '%s' "$_JSON_BIN"; }

# 跑 jq 程序（$@ 原样转发）。调用点优先用它：省掉取路径的那次命令替换，调用点也更短。
json.run() { "$_JSON_BIN" "$@"; }

# 从 JSON 文本里取一个值（filter 缺省取整个文档）；解析失败返回非 0、不吞错
json.get() { "$_JSON_BIN" -r "${2:-.}" <<< "$1"; }
