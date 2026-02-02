#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import core/help
	unset _SCRIPT_NAME _SCRIPT_DESC 2>/dev/null || true
}

teardown() {
	unset _SCRIPT_NAME _SCRIPT_DESC 2>/dev/null || true
}

@test "help.show - 显示完整帮助" {
	_SCRIPT_NAME="test"
	_SCRIPT_DESC="Test script"

	declare -A opts=(
		["-h, --help"]="Show help"
		["-v, --verbose"]="Verbose output"
		["-f, --file FILE"]="Input file"
	)
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(help.show opts args examples notices 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"Options"* ]]
	[[ "$output" == *"for subcommand help"* ]]
}

@test "help.show - 包含描述时显示标题" {
	_SCRIPT_NAME="myapp"
	_SCRIPT_DESC="Process files"

	declare -A opts=(["-h, --help"]="Show help")
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(help.show opts args examples notices 2>&1)
	[[ "$output" == *"myapp"* ]]
	[[ "$output" == *"Process files"* ]]
}

@test "help.show - 无描述时只显示名称" {
	_SCRIPT_NAME="simple"
	unset _SCRIPT_DESC 2>/dev/null || true

	declare -A opts=(["-h, --help"]="Show help")
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(help.show opts args examples notices 2>&1)
	[[ "$output" == *"simple"* ]]
}

@test "help.show - 包含notices" {
	_SCRIPT_NAME="test"
	_SCRIPT_DESC="Test"

	declare -A opts=(["-h, --help"]="Show help")
	declare -A args=()
	declare -A examples=()
	declare -A notices=(["Important notice"]="")

	output=$(help.show opts args examples notices 2>&1)
	[[ "$output" == *"Notices"* ]]
	[[ "$output" == *"Important notice"* ]]
}

@test "help.show - 只有选项时Usage显示[OPTIONS]" {
	_SCRIPT_NAME="cmd"
	_SCRIPT_DESC="Test"

	declare -A opts=(["-h, --help"]="Show help" ["-v, --verbose"]="Verbose")
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(help.show opts args examples notices 2>&1)
	[[ "$output" == *"[OPTIONS]"* ]]
	[[ "$output" != *"[ARGUMENTS]"* ]]
}

@test "help.show - 有选项和参数时Usage显示两者" {
	_SCRIPT_NAME="cmd"
	_SCRIPT_DESC="Test"

	declare -A opts=(["-h, --help"]="Show help" ["-f, --file FILE"]="File")
	declare -A args=(["input"]="Input file")
	declare -A examples=()
	declare -A notices=()

	output=$(help.show opts args examples notices 2>&1)
	[[ "$output" == *"[OPTIONS]"* ]]
	[[ "$output" == *"[ARGUMENTS]"* ]]
	[[ "$output" == *"Arguments"* ]]
}

@test "help.show - 空选项和空参数时Usage不显示可选部分" {
	_SCRIPT_NAME="cmd"
	_SCRIPT_DESC="Test"

	declare -A opts=()
	declare -A args=()
	declare -A examples=()
	declare -A notices=()

	output=$(help.show opts args examples notices 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" != *"[OPTIONS]"* ]]
	[[ "$output" != *"[ARGUMENTS]"* ]]
}

@test "help.section.items - 正确显示映射项" {
	declare -A items=(
		["-h, --help"]="Show help"
		["-v, --verbose"]="Verbose output"
	)

	output=$(help.section.items items 2>&1)
	[[ "$output" == *"-h, --help"* ]]
	[[ "$output" == *"Show help"* ]]
}

@test "help.usage.oneline - 有选项时显示[OPTIONS]" {
	_SCRIPT_NAME="test"

	output=$(help.usage.oneline 1 0 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"[OPTIONS]"* ]]
}

@test "help.usage.oneline - 有参数时显示[ARGUMENTS]" {
	_SCRIPT_NAME="test"

	output=$(help.usage.oneline 0 1 2>&1)
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"[ARGUMENTS]"* ]]
}

@test "help.usage.oneline - 两者都有时显示完整" {
	_SCRIPT_NAME="test"

	output=$(help.usage.oneline 1 1 2>&1)
	[[ "$output" == *"[OPTIONS]"* ]]
	[[ "$output" == *"[ARGUMENTS]"* ]]
}
