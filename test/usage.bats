#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import core/usage
	unset _SCRIPT_NAME _SCRIPT_DESC 2>/dev/null || true
	unset _ARGS_CURRENT_SUBCOMMAND 2>/dev/null || true
	declare -g _ARGS_CURRENT_SUBCOMMAND=""
	declare -gA _ARGS_SUBCOMMANDS=()
}

teardown() {
	unset _SCRIPT_NAME _SCRIPT_DESC 2>/dev/null || true
}

@test "usage.show - 显示完整帮助" {
	_SCRIPT_NAME="test"
	_SCRIPT_DESC="Test script"
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
	_SCRIPT_NAME="myapp"
	_SCRIPT_DESC="Process files"

	declare -A opts=(["-h, --help"]="Show help")
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(usage.show opts args examples notices 2>&1)
	[[ "$output" == *"myapp"* ]]
	[[ "$output" == *"Process files"* ]]
}

@test "usage.show - 无描述时只显示名称" {
	_SCRIPT_NAME="simple"
	unset _SCRIPT_DESC 2>/dev/null || true

	declare -A opts=(["-h, --help"]="Show help")
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(usage.show opts args examples notices 2>&1)
	[[ "$output" == *"simple"* ]]
}

@test "usage.show - 包含notices" {
	_SCRIPT_NAME="test"
	_SCRIPT_DESC="Test"

	declare -A opts=(["-h, --help"]="Show help")
	declare -A args=()
	declare -A examples=()
	declare -A notices=(["Important notice"]="")

	output=$(usage.show opts args examples notices 2>&1)
	[[ "$output" == *"Notices"* ]]
	[[ "$output" == *"Important notice"* ]]
}

@test "usage.show - 只有选项时Usage显示[OPTIONS]" {
	_SCRIPT_NAME="cmd"
	_SCRIPT_DESC="Test"

	declare -A opts=(["-h, --help"]="Show help" ["-v, --verbose"]="Verbose")
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(usage.show opts args examples notices 2>&1)
	[[ "$output" == *"[OPTIONS]"* ]]
	[[ "$output" != *"[ARGUMENTS]"* ]]
}

@test "usage.show - 有选项和参数时Usage显示两者" {
	_SCRIPT_NAME="cmd"
	_SCRIPT_DESC="Test"

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
	_SCRIPT_NAME="cmd"
	_SCRIPT_DESC="Test"

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
	_SCRIPT_NAME="test"

	output=$(usage.usage 1 0 0 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"<subcommand>"* ]]
}

@test "usage.usage - 有具体子命令时显示具体命令" {
	_SCRIPT_NAME="test"
	_ARGS_CURRENT_SUBCOMMAND="test-command"

	output=$(usage.usage 1 0 0 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"test-command"* ]]
}

@test "usage.usage - 有选项时显示[OPTIONS]" {
	_SCRIPT_NAME="test"

	output=$(usage.usage 0 1 0 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"[OPTIONS]"* ]]
}

@test "usage.usage - 有参数时显示[ARGUMENTS]" {
	_SCRIPT_NAME="test"

	output=$(usage.usage 0 0 1 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"[ARGUMENTS]"* ]]
}

@test "usage.usage - 两者都有时显示完整" {
	_SCRIPT_NAME="test"

	output=$(usage.usage 1 1 1 2>&1)
	[[ "$output" == *"<subcommand>"* ]]
	[[ "$output" == *"[OPTIONS]"* ]]
	[[ "$output" == *"[ARGUMENTS]"* ]]
}

@test "usage.show - 显示 Commands 部分当有子命令描述" {
	_SCRIPT_NAME="myapp"
	_SCRIPT_DESC="Application"
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
	_SCRIPT_NAME="myapp"
	_SCRIPT_DESC="Application"
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
	_SCRIPT_NAME="test"
	_SCRIPT_DESC="Test script"

	declare -A opts=(["-h, --help"]="Show help")
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(usage.show opts args examples notices 2>&1)
	# 输出应该以空行开始
	[[ "${output:0:1}" == $'\n' ]] || [[ "$output" =~ ^[[:space:]] ]]
}
