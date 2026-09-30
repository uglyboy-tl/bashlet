#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import std/console.epipe
}

@test "console.epipe.init - 忽略 SIGPIPE" {
	# 写到文件以绕过 init 对 stdout 的重定向
	local t="$BATS_TEST_TMPDIR/trap"
	run bash -c 'source "$1/lib/std/import.sh"; import std/console.epipe; console.epipe.init /dev/null; trap -p PIPE > "$2"' _ "$PROJECT_ROOT" "$t"
	run cat "$t"
	assert_output --partial "SIGPIPE"
}

@test "console.epipe.init - stdout 非 tty 时输出重定向到日志" {
	local log="$BATS_TEST_TMPDIR/e.log"
	run bash -c 'source "$1/lib/std/import.sh"; import std/console.epipe; console.epipe.init "$2"; echo hello' _ "$PROJECT_ROOT" "$log"
	[ -z "$output" ]
	run cat "$log"
	assert_output "hello"
}

@test "console.epipe.init - 指定日志会自动创建父目录" {
	local log="$BATS_TEST_TMPDIR/sub/dir/e.log"
	run bash -c 'source "$1/lib/std/import.sh"; import std/console.epipe; console.epipe.init "$2"; echo x' _ "$PROJECT_ROOT" "$log"
	[[ -f $log ]]
	run cat "$log"
	assert_output "x"
}

@test "console.epipe.init - 显式重定向到文件时不劫持" {
	local out="$BATS_TEST_TMPDIR/out.txt" log="$BATS_TEST_TMPDIR/log"
	bash -c 'source "$1/lib/std/import.sh"; import std/console.epipe; console.epipe.init "$2"; echo hello' _ "$PROJECT_ROOT" "$log" > "$out"
	run cat "$out"
	assert_output "hello"
	[[ ! -e $log ]]
}

@test "console.epipe.init - CONSOLE_EPIPE_KEEP_STDOUT 时不劫持" {
	local log="$BATS_TEST_TMPDIR/log"
	run env CONSOLE_EPIPE_KEEP_STDOUT=1 bash -c 'source "$1/lib/std/import.sh"; import std/console.epipe; console.epipe.init "$2"; echo hi' _ "$PROJECT_ROOT" "$log"
	assert_output "hi"
	[[ ! -e $log ]]
}
