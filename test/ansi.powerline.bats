#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import std/ansi.powerline
}

# ============ 能力检测 ============

@test "ansi.Powerline.IsAvailable - 返回函数" {
	run ansi.Powerline.IsAvailable
	[[ $status -eq 0 || $status -eq 1 ]]
}

# ============ 启用/禁用 ============

@test "ansi.enable.powerline() 设置 Powerline 变量" {
	run ansi.enable.powerline
	[[ $status -eq 0 ]]
}

@test "ansi.disable.powerline() 重置 Powerline 为 ASCII" {
	ansi.disable.powerline
	[[ $POWERLINE_SEPARATOR == ">" ]]
	[[ $POWERLINE_BRANCH == "|}" ]]
	[[ $POWERLINE_OK == "+" ]]
}

@test "import 期就绪：字形变量已可读" {
	[[ -n $POWERLINE_OK && -n $POWERLINE_SEPARATOR ]]
}

# ============ 使用场景 ============

@test "使用 Powerline 变量" {
	ansi.disable.powerline
	local prompt="${POWERLINE_SEPARATOR} prompt"
	[[ $prompt == "> prompt" ]]

	ansi.enable.powerline
	[[ -n $POWERLINE_SEPARATOR ]]
}

@test "组合颜色、样式和 Powerline" {
	ansi.enable.color
	ansi.enable.style
	local msg="${RED}${Bold}Error${NC}: ${POWERLINE_FAIL} failed"
	[[ -n $msg ]]
}

@test "使用 Powerline 分隔符构建 prompt" {
	ansi.enable.color
	ansi.enable.powerline
	local prompt="${GREEN} user ${NC}${POWERLINE_SEPARATOR}${BLUE} dir ${NC}${POWERLINE_SEPARATOR}${NC}"
	[[ -n $prompt ]]
}

@test "Git 提示符：使用 Powerline 分支符号" {
	ansi.enable.powerline
	local git_prompt="${POWERLINE_BRANCH} main"
	[[ -n $git_prompt ]]
}

@test "状态显示：使用 Powerline 符号表示状态" {
	ansi.disable.powerline
	local success="${POWERLINE_OK} Done"
	local failed="${POWERLINE_FAIL} Failed"

	[[ $success == "+ Done" ]]
	[[ $failed == "x Failed" ]]
}

# ============ 降级 ============

@test "_ANSI_FORCE_DISABLE 时 import 期降级为 ASCII" {
	run env _ANSI_FORCE_DISABLE=1 bash -c '
		set -euo pipefail
		source "$1"
		import std/ansi.powerline
		[[ $POWERLINE_OK == "+" && $POWERLINE_SEPARATOR == ">" ]]
	' _ "$PROJECT_ROOT/lib/std/import.sh"
	assert_success
}

@test "NO_UNICODE 时 import 期降级为 ASCII" {
	run env NO_UNICODE=1 bash -c '
		set -euo pipefail
		source "$1"
		import std/ansi.powerline
		[[ $POWERLINE_OK == "+" ]]
	' _ "$PROJECT_ROOT/lib/std/import.sh"
	assert_success
}
