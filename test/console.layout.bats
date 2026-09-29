#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import std/console.layout
}

# ========== console.layout.item ==========

@test "console.layout.item.title - 基本标题" {
	run console.layout.item.title 0 "Main Title"
	[ "$status" -eq 0 ]
	[[ $output == *"Main Title"* ]]
}

@test "console.layout.item.title - 带缩进级别" {
	run console.layout.item.title 2 "Sub Title"
	[ "$status" -eq 0 ]
	[[ $output == *"Sub Title"* ]]
}

@test "console.layout.item.item - 基本项目" {
	_CONSOLE_LAYOUT_DEPTH=1
	run console.layout.item.item "item content"
	[ "$status" -eq 0 ]
	[[ $output == *"item content"* ]]
}

@test "console.layout.item.item - 未先调 title 也不受 set -u 影响" {
	run bash -c 'set -euo pipefail; source "$1"; import std/console.layout; console.layout.item.item "x"' _ "$PROJECT_ROOT/lib/std/import.sh"
	[ "$status" -eq 0 ]
	[[ $output == *"x"* ]]
}

@test "console.layout.item.mid - 中间项目" {
	_CONSOLE_LAYOUT_DEPTH=1
	run console.layout.item.mid "middle item"
	[ "$status" -eq 0 ]
	[[ $output == *"├─"* ]]
	[[ $output == *"middle item"* ]]
}

@test "console.layout.item.end - 结束项目" {
	_CONSOLE_LAYOUT_DEPTH=1
	run console.layout.item.end "last item"
	[ "$status" -eq 0 ]
	[[ $output == *"└─ last item"* ]]
}

# ========== console.layout.section ==========

@test "console.layout.section - 下划线长度等于标题显示宽度" {
	run console.layout.section "ABCDE"
	[ "$status" -eq 0 ]
	[[ $output == *"======"* ]]
}

@test "console.layout.section - 超过缓存长度的标题被截断（已知限制）" {
	local title="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" # 宽度 30 > 缓存 20
	local underline
	underline=$(printf '%*s' 20 '' | tr ' ' '=')
	run console.layout.section "$title"
	[[ $output == *"=$underline"* ]]
}

@test "console.layout.section - 基本标题输出" {
	run console.layout.section "Title"
	[ "$status" -eq 0 ]
	[[ $output == *"Title:"* ]]
	[[ $output == *"====="* ]]
}

@test "console.layout.section - 中文标题" {
	run console.layout.section "章节"
	[ "$status" -eq 0 ]
	[[ $output == *"章节:"* ]]
}

# ========== console.layout.footer ==========

@test "console.layout.footer - 基本页脚" {
	run console.layout.footer "Footer Text"
	[ "$status" -eq 0 ]
	[[ $output == *"========="* ]]
	[[ $output == *"Footer Text"* ]]
}
