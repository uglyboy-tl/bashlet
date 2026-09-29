#!/usr/bin/env bash

import std/console

# 终端组合型/装饰型渲染层。构建在 console 原语之上；core/log 只依赖原语，不依赖本层，
# 以保证日志底座最小（见 docs/adr/0001）。

# 下划线缓存：section 可能反复调用，切片即可，避免每次生成。
# 注：标题超过缓存长度会被截断（实际标题都很短，忽略）。
_CONSOLE_LAYOUT_UNDERLINE=$(console.repeat "=" 20)

# 默认缩进:允许在未先调 item.title/section 时直接使用 item.*（set -u 安全）
_CONSOLE_LAYOUT_DEPTH=0

console.layout.section() {
	console.stdout "$1:"
	console.stdout "=${_CONSOLE_LAYOUT_UNDERLINE:0:$(console.display_width "$1")}"
}

console.layout.footer() {
	console.stdout "========="
	console.stdout "${*}"
}

console.layout.item.title() {
	console.indent "$1" "${*:2}"
	_CONSOLE_LAYOUT_DEPTH=$(($1 + 1))
}

console.layout.item.item() {
	console.indent "${_CONSOLE_LAYOUT_DEPTH}" "${*}"
}

console.layout.item.mid() {
	console.layout.item.item "├─" "${*}"
}

console.layout.item.end() {
	console.layout.item.item "└─" "${*}"
	echo ""
}
