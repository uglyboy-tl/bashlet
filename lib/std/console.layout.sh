#!/usr/bin/env bash

import std/console

# 终端组合型/装饰型渲染层。构建在 console 原语之上；core/log 只依赖原语，不依赖本层，
# 以保证日志底座最小（见 docs/adr/0001）。

# 下划线缓存：section 可能反复调用，切片即可，避免每次生成。
# 注：标题超过缓存长度会被截断（实际标题都很短，忽略）。
_CONSOLE_LAYOUT_UNDERLINE=$(console.repeat "=" 20)

# 默认缩进:允许在未先调 item.title/section 时直接使用 item.*（set -u 安全）
_CONSOLE_LAYOUT_DEPTH=0

# 自上次 section 以来是否输出过条目。初值 1：没经过 section 直接调 footer，
# 那条分隔线仍是必要的。用于避免「section 下划线 + footer 分隔线」贴成两条。
_CONSOLE_LAYOUT_ITEM_SEEN=1

console.layout.section() {
	console.stdout "$1:"
	console.stdout "=${_CONSOLE_LAYOUT_UNDERLINE:0:$(console.display_width "$1")}"
	_CONSOLE_LAYOUT_ITEM_SEEN=0
}

console.layout.footer() {
	((_CONSOLE_LAYOUT_ITEM_SEEN)) && console.stdout "========="
	console.stdout "${*}"
}

console.layout.item.title() {
	console.indent "$1" "${*:2}"
	_CONSOLE_LAYOUT_DEPTH=$(($1 + 1))
	_CONSOLE_LAYOUT_ITEM_SEEN=1
}

console.layout.item.item() {
	console.indent "${_CONSOLE_LAYOUT_DEPTH}" "${*}"
	_CONSOLE_LAYOUT_ITEM_SEEN=1
}

# 调用方自行渲染条目（如直接用 printf 画表格）时，在输出前调一次：不产出任何内容，
# 只置位标志让 footer 知道本轮有内容。标志是 shell 变量，在 $(...) / 管道 / 后台作业里
# 调 item.* 不会回传父 shell，footer 会静默少一条分隔线，所以 item.* 要与 footer 同 shell。
console.layout.item.raw() { _CONSOLE_LAYOUT_ITEM_SEEN=1; }

console.layout.item.mid() {
	console.layout.item.item "├─" "${*}"
}

console.layout.item.end() {
	console.layout.item.item "└─" "${*}"
	echo ""
}
