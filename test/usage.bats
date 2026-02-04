#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import core/usage
	unset _USAGE_SCRIPT_NAME _USAGE_SCRIPT_DESC _ARGS_CURRENT_SUBCOMMAND 2>/dev/null || true
	declare -g _ARGS_CURRENT_SUBCOMMAND=""
	declare -gA _ARGS_SUBCOMMANDS=()
}

teardown() {
	unset _USAGE_SCRIPT_NAME _SCRIPT_DESC 2>/dev/null || true
}

@test "usage.show - 显示完整帮助" {
	_ARGS_SUBCOMMANDS["test"]="test_handler"

	declare -A opts=(
		["-h, --help"]="Show help"
		["-v, --verbose"]="Verbose output"
		["-f, --file FILE"]="Input file"
	)
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(usage.show opts args examples notices 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"Options"* ]]
	[[ "$output" == *"for subcommand help"* ]]
}

@test "usage.show - 包含描述时显示标题" {
	_USAGE_SCRIPT_NAME="myapp"
	_USAGE_SCRIPT_DESC="Process files"

	declare -A opts=(["-h, --help"]="Show help")
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(usage.show opts args examples notices 2>&1)
	[[ "$output" == *"myapp"* ]]
	[[ "$output" == *"Process files"* ]]
}

@test "usage.show - 无描述时只显示名称" {
	_USAGE_SCRIPT_NAME="simple"
	unset _USAGE_SCRIPT_DESC 2>/dev/null || true

	declare -A opts=(["-h, --help"]="Show help")
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(usage.show opts args examples notices 2>&1)
	[[ "$output" == *"simple"* ]]
}

@test "usage.show - 包含notices" {
	declare -A opts=(["-h, --help"]="Show help")
	declare -A args=()
	declare -A examples=()
	declare -A notices=(["Important notice"]="")

	output=$(usage.show opts args examples notices 2>&1)
	[[ "$output" == *"Notices"* ]]
	[[ "$output" == *"Important notice"* ]]
}

@test "usage.show - 只有选项时Usage显示[OPTIONS]" {
	declare -A opts=(["-h, --help"]="Show help" ["-v, --verbose"]="Verbose")
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(usage.show opts args examples notices 2>&1)
	[[ "$output" == *"[OPTIONS]"* ]]
	[[ "$output" != *"[ARGUMENTS]"* ]]
}

@test "usage.show - 有选项和参数时Usage显示两者" {
	declare -A opts=(["-h, --help"]="Show help" ["-f, --file FILE"]="File")
	declare -A args=(["input"]="Input file")
	declare -A examples=()
	declare -A notices=()

	output=$(usage.show opts args examples notices 2>&1)
	[[ "$output" == *"[OPTIONS]"* ]]
	[[ "$output" == *"[ARGUMENTS]"* ]]
	[[ "$output" == *"Arguments"* ]]
}

@test "usage.show - 空选项和空参数时Usage不显示可选部分" {
	declare -A opts=()
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(usage.show opts args examples notices 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" != *"[OPTIONS]"* ]]
	[[ "$output" != *"[ARGUMENTS]"* ]]
}

@test "usage.section.items - 正确显示映射项" {
	declare -A items=(
		["-h, --help"]="Show help"
		["-v, --verbose"]="Verbose output"
	)

	output=$(usage.section.items items 2>&1)
	[[ "$output" == *"-h, --help"* ]]
	[[ "$output" == *"Show help"* ]]
}

@test "usage.usage - 存在子命令时显示<subcommand>" {
	output=$(usage.usage 1 0 0 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"<subcommand>"* ]]
}

@test "usage.usage - 有具体子命令时显示具体命令" {
	_ARGS_CURRENT_SUBCOMMAND="test-command"

	output=$(usage.usage 1 0 0 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"test-command"* ]]
}

@test "usage.usage - 有选项时显示[OPTIONS]" {
	output=$(usage.usage 0 1 0 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"[OPTIONS]"* ]]
}

@test "usage.usage - 有参数时显示[ARGUMENTS]" {
	output=$(usage.usage 0 0 1 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"[ARGUMENTS]"* ]]
}

@test "usage.usage - 两者都有时显示完整" {
	output=$(usage.usage 1 1 1 2>&1)
	[[ "$output" == *"<subcommand>"* ]]
	[[ "$output" == *"[OPTIONS]"* ]]
	[[ "$output" == *"[ARGUMENTS]"* ]]
}

@test "usage.show - 显示 Commands 部分当有子命令描述" {
	declare -gA _ARGS_SUBCOMMANDS_DESC=(
		["build"]="构建项目"
		["test"]="运行测试"
	)

	declare -A opts=(["-h, --help"]="显示帮助")
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(usage.show opts args examples notices 2>&1)
	[[ "$output" == *"Commands"* ]] || [[ "$output" == *"commands"* ]]
	[[ "$output" == *"build"* ]]
	[[ "$output" == *"构建项目"* ]]
	[[ "$output" == *"test"* ]]
	[[ "$output" == *"运行测试"* ]]
}

@test "usage.show - 子命令模式下不显示 Commands 部分" {
	declare -g _ARGS_CURRENT_SUBCOMMAND="build"
	declare -gA _ARGS_SUBCOMMANDS_DESC=(
		["build"]="构建项目"
	)

	declare -A opts=(["-h, --help"]="显示帮助")
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(usage.show opts args examples notices 2>&1)
	# 在子命令模式下不显示 Commands 部分
	[[ "$output" != *"Commands"* ]] || [[ "$output" != *"commands"* ]]
	[[ "$output" != *"for subcommand help"* ]]
}

@test "usage.show - 输出以空行开始" {
	declare -A opts=(["-h, --help"]="Show help")
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(usage.show opts args examples notices 2>&1)
	# 输出应该以空行开始
	[[ "${output:0:1}" == $'\n' ]] || [[ "$output" =~ ^[[:space:]] ]]
}

# ========== usage.version 测试（新增测试用例） ==========

@test "usage.version - 显示版本信息" {
	_USAGE_SCRIPT_NAME="myapp"
	VERSION="1.0.0"
	
	output=$(usage.version 2>&1)
	[[ "$output" == *"myapp"* ]]
	[[ "$output" == *"version"* ]]
	[[ "$output" == *"1.0.0"* ]]
}

@test "usage.version - 使用彩色输出" {
	_USAGE_SCRIPT_NAME="testapp"
	VERSION="2.3.4"
	
	output=$(usage.version 2>&1)
	# 检查是否包含ANSI颜色代码
	[[ "$output" == *$BRIGHT_CYAN* ]] || [[ "$output" == *"\033["* ]]
	[[ "$output" == *$BRIGHT_GREEN* ]] || [[ "$output" == *"\033["* ]]
	[[ "$output" == *$NC* ]] || [[ "$output" == *"\033["* ]]
}

@test "usage.version - 脚本名未设置时使用默认值" {
	unset _USAGE_SCRIPT_NAME
	VERSION="0.1.0"
	
	output=$(usage.version 2>&1)
	# 应该输出版本信息，即使脚本名是默认值
	[[ "$output" == *"version"* ]]
	[[ "$output" == *"0.1.0"* ]]
}

@test "usage.version - 总是返回状态码 0" {
	_USAGE_SCRIPT_NAME="test"
	VERSION="1.0"
	
	run usage.version
	[ "$status" -eq 0 ]
}

@test "usage.version - 空版本号也正常工作" {
	_USAGE_SCRIPT_NAME="app"
	VERSION=""
	
	output=$(usage.version 2>&1)
	[[ "$output" == *"app"* ]]
	[[ "$output" == *"version"* ]]
}
