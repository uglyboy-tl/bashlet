#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import std/console
}

teardown() {
	# 清理环境变量
	unset console 2>/dev/null || true
}

@test "console.stderr - 基本输出到 stderr" {
	run console.stderr "test message"
	[ "$status" -eq 0 ]
	[ "$output" = "test message" ]
}

@test "console.stderr - 多个参数正确连接" {
	run console.stderr "hello" "world"
	[ "$status" -eq 0 ]
	[ "$output" = "hello world" ]
}

@test "console.stderr - 空参数输出空行" {
	run console.stderr ""
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "console.stderr - 无参数输出空行" {
	run console.stderr
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "console.stderr - 特殊字符处理" {
	run console.stderr "test with \$VAR"
	[ "$status" -eq 0 ]
	[ "$output" = 'test with $VAR' ]
}

@test "console.stderr - 多行消息" {
	run console.stderr "line1" "line2" "line3"
	[ "$status" -eq 0 ]
	[ "$output" = "line1 line2 line3" ]
}

# ========== console.format 测试 ==========

@test "console.format - 基本格式化输出" {
	run console.format 20 "test" "desc"
	[ "$status" -eq 0 ]
	# test (4字符) + 16 空格 = 20字符 + desc (4字符) + 换行符 = 25字符
	# 但在 bats 中 ${#output} 计算字符数 = 24 (不包含换行符)
	[ "${#output}" -eq 24 ]
}

@test "console.format - 文本长度等于宽度不填充" {
	run console.format 4 "test" "desc"
	[ "$status" -eq 0 ]
	[ "$output" = "testdesc" ]
}

@test "console.format - 文本长度超过宽度" {
	run console.format 3 "test" "desc"
	[ "$status" -eq 0 ]
	[ "$output" = "testdesc" ]
}

@test "console.format - 空文本处理" {
	run console.format 10 "" "desc"
	[ "$status" -eq 0 ]
	# 10空格 + desc
	[ "${#output}" -eq 14 ]  # 10 + 4 (desc)
}

@test "console.format - 空描述处理" {
	run console.format 10 "test" ""
	[ "$status" -eq 0 ]
	# test (4字符) + 6空格 = 10字符 + 换行符 = 11字节
	# bats ${#output} 计算字符数 = 10
	[ "${#output}" -eq 10 ]
}

@test "console.format - ANSI 转义码不被计入宽度" {
	local red=$'\x1b[31m'    # 5字节
	local reset=$'\x1b[0m'   # 4字节

	# width=10, 可见字符="test"(4), padding=6
	# 输出: red(5) + test(4) + reset(4) + 空格(6) + desc(4) + 换行(1)
	#      = 5+4+4+6+4+1 = 24 字节
	run console.format 10 "${red}test${reset}" "desc"
	[ "$status" -eq 0 ]
	[ "${#output}" -eq 23 ]  # 24-1 (不含换行符)
}

@test "console.format - 多个 ANSI 转义码正确处理" {
	local red=$'\x1b[31m'    # 5字节
	local green=$'\x1b[32m'  # 5字节
	local reset=$'\x1b[0m'   # 4字节

	# width=10, 可见字符="test"(4), padding=6
	# 输出: red(5) + te(2) + green(5) + st(2) + reset(4) + 空格(6) + desc(4) + 换行(1)
	#      = 5+2+5+2+4+6+4+1 = 29 字节
	run console.format 10 "${red}te${green}st${reset}" "desc"
	[ "$status" -eq 0 ]
	[ "${#output}" -eq 28 ]  # 29-1 (不含换行符)
}

@test "console.format - 长数字 ANSI 参数处理" {
	local color=$'\x1b[38;2;255;0;0m'  # 15字节
	local reset=$'\x1b[0m'             # 4字节

	# width=10, 可见字符="test"(4), padding=6
	# 输出: color(15) + test(4) + reset(4) + 空格(6) + desc(4) + 换行(1)
	#      = 15+4+4+6+4+1 = 34 字节
	run console.format 10 "${color}test${reset}" "desc"
	[ "$status" -eq 0 ]
	[ "${#output}" -eq 33 ]  # 34-1 (不含换行符)
}

@test "console.format - 未闭合的 ANSI 转义码" {
	local red=$'\x1b[31m'  # 5字节 (无重置码)

	# width=10, 可见字符="test"(4), padding=6
	# 输出: red(5) + test(4) + 空格(6) + desc(4) + 换行(1)
	#      = 5+4+6+4+1 = 20 字节
	run console.format 10 "${red}test" "desc"
	[ "$status" -eq 0 ]
	[ "${#output}" -eq 19 ]  # 20-1 (不含换行符)
}

@test "console.format - 零宽度边界" {
	run console.format 0 "test" "desc"
	[ "$status" -eq 0 ]
	[ "$output" = "testdesc" ]
}

@test "console.format - 宽度为1" {
	run console.format 1 "t" "desc"
	[ "$status" -eq 0 ]
	[ "${#output}" -eq 5 ]  # t + desc + 换行符
}

@test "console.format - 非常大的宽度" {
	run console.format 1000 "test" "desc"
	[ "$status" -eq 0 ]
	# test + 996空格 + desc + 换行符
	[ "${#output}" -eq 1004 ]
}

@test "console.format - 多字节字符处理" {
	run console.format 10 "测试" "desc"
	[ "$status" -eq 0 ]
	# 2中文字符(4字节) + 6空格 + desc + 换行符
	# 注意: ${#}计算字符数，但 printf 格式化按字节
	# 当前实现按字符数填充空格
	[ "${#output}" -ge 11 ]
}

@test "console.format - 特殊字符在文本中" {
	run console.format 10 "test\$VAR" "desc"
	[ "$status" -eq 0 ]
	# test\$VAR (8) + 2空格 + desc (4) + 换行符 (1) = 15字节
	# bats ${#output} 计算字符数 = 14
	[ "${#output}" -eq 14 ]
}

@test "console.format - 换行符在描述中" {
	run console.format 10 "test" "desc
with newline"
	[ "$status" -eq 0 ]
	[[ "$output" == *"desc"* ]]
}
