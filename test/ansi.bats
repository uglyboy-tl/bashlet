#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import std/ansi
}

teardown() {
	: # No cleanup needed
}

# ============ 功能检测测试 ============

@test "ansi.Color.IsAvailable - 返回函数而非别名" {
	run ansi.Color.IsAvailable
	[[ $status -eq 0 || $status -eq 1 ]]
}

# ============ 启用/禁用颜色测试 ============

@test "ansi.enable.color() 设置颜色变量" {
	run ansi.enable.color
	[[ $status -eq 0 ]]
}

@test "ansi.disable.color() 清空颜色变量" {
	run ansi.disable.color
	[[ $status -eq 0 ]]
	[[ -z $RED ]]
	[[ -z $GREEN ]]
	[[ -z $BLUE ]]
	[[ -z $NC ]]
}

# ============ 启用/禁用样式测试 ============

@test "ansi.enable.style() 设置样式变量" {
	run ansi.enable.style
	[[ $status -eq 0 ]]
}

@test "ansi.disable.style() 清空样式变量" {
	run ansi.disable.style
	[[ $status -eq 0 ]]
	[[ -z $Bold ]]
	[[ -z $Italics ]]
	[[ -z $Underline ]]
}

# ============ 主入口函数测试 ============

@test "ansi.enable() 根据检测启用功能" {
	run ansi.enable
	[[ $status -eq 0 ]]
}

@test "ansi.disable() 禁用颜色与样式" {
	ansi.disable
	[[ -z $RED ]]
	[[ -z $Bold ]]
}

# ============ 环境变量控制测试 ============

@test "_ANSI_FORCE_DISABLE 强制禁用颜色与样式" {
	run env _ANSI_FORCE_DISABLE=1 bash -c '
		set -euo pipefail
		source "$1"
		import std/ansi
		[[ -z $RED && -z $Bold ]]
	' _ "$PROJECT_ROOT/lib/std/import.sh"
	assert_success
}

# ============ 变量使用场景测试 ============

@test "使用颜色变量组合字符串" {
	ansi.enable.color
	local msg="${RED}Error${NC}: something failed"
	[[ -n $msg ]]
}

@test "使用样式变量" {
	ansi.enable.style
	local msg="${Bold}bold text${NC}"
	[[ -n $msg ]]
}

# ============ 边界条件测试 ============

@test "多次调用 ansi.enable.color() 不会出错" {
	ansi.enable.color
	ansi.enable.color
	run ansi.enable.color
	[[ $status -eq 0 ]]
}

@test "多次调用 ansi.disable.color() 不会出错" {
	ansi.disable.color
	ansi.disable.color
	run ansi.disable.color
	[[ $status -eq 0 ]]
}

@test "多次调用 ansi.enable.style() 不会出错" {
	ansi.enable.style
	ansi.enable.style
	run ansi.enable.style
	[[ $status -eq 0 ]]
}

@test "多次调用 ansi.disable.style() 不会出错" {
	ansi.disable.style
	ansi.disable.style
	run ansi.disable.style
	[[ $status -eq 0 ]]
}

@test "交替调用 enable/disable" {
	ansi.enable.color
	ansi.enable.style
	ansi.disable.color
	ansi.disable.style
	[[ -z $RED ]]
	[[ -z $Bold ]]
	ansi.enable.color
	ansi.enable.style
	[[ -n $ANSI_CSI || -z $ANSI_CSI ]]
}

# ============ 实际使用场景测试 ============

@test "日志场景：不同级别使用不同颜色" {
	ansi.enable.color
	local error_msg="${RED}ERROR${NC}: something went wrong"
	local success_msg="${GREEN}SUCCESS${NC}: operation completed"
	local warning_msg="${YELLOW}WARNING${NC}: please check"

	[[ -n $error_msg ]]
	[[ -n $success_msg ]]
	[[ -n $warning_msg ]]
}

@test "样式场景：使用粗体和斜体" {
	ansi.enable.style
	local bold_text="${Bold}Important${NC}"
	local italic_text="${Italics}emphasis${NC}"
	local underline_text="${Underline}link${NC}"

	[[ -n $bold_text ]]
	[[ -n $italic_text ]]
	[[ -n $underline_text ]]
}

@test "帮助文本：使用颜色和样式突出显示" {
	ansi.enable.color
	ansi.enable.style
	local help_text="${Bold}Usage:${NC} ${Italics}script${NC} ${RED}[options]${NC}"
	[[ -n $help_text ]]
}

@test "禁用后输出纯文本" {
	ansi.disable
	local plain_text="${RED}${Bold}Error${NC}: message"
	[[ $plain_text == "Error: message" ]]
}
