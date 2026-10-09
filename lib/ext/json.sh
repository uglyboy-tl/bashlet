#!/usr/bin/env bash

import core/log

# jq 的唯一入口。顶层只**定位**、不探活：探活放在真正要用 jq 的那一刻（json.run / json.get），
# 这样缺 jq 的机器上 --help / -v / doctor 之类仍然可用，而不是一加载就死。
# requests.init 里也探一次（它在主 shell，比子 shell 里的 exit 有用）。
# 需要「接住再降级」的调用方（doctor 的 probe、provider 表）用 json.available 显式探活。
#
# 不进 std/：jq 与 curl / fzf 同属 ext 的「可选重能力」（std/ 只放 coreutils 类）。

declare -g _JSON_BIN
_JSON_BIN="$(command -v jq 2> /dev/null || true)"

# jq 是否可用（0=可用、非 0=缺）
json.available() { [[ -n $_JSON_BIN ]]; }

# 缺 jq 时报错并退出。**调用方应在自己的入口（确定在主 shell 的位置）调一次**：
# json.run 的 fail-fast 在 $(...) / 管道里只杀子 shell，调用方看不到失败，会静默落到
# 误导性分支（把解析失败报成「数据不存在」之类）。这是本模块唯一的 fail-loud 出口。
json.require() {
	json.available && return 0
	log.error "required command not found: jq"
	exit 1
}

# 跑 jq 程序（$@ 原样转发）。调用点优先用它：省掉取路径的那次命令替换，调用点也更短。
json.run() {
	json.require
	"$_JSON_BIN" "$@"
}

# 从 JSON 文本里取一个值（filter 缺省取整个文档）；解析失败返回非 0、不吞错
json.get() {
	json.require
	"$_JSON_BIN" -r "${2:-.}" <<< "$1"
}
