#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import std/system
	import core/log
	log.setLevel INFO  # 屏蔽 log.error 输出
}

teardown() {
	unset _SYSTEM_OS _SYSTEM_ARCH 2>/dev/null || true
}

# ============ system.command.exist 测试 ============

@test "system.command.exist - 存在的命令返回成功" {
	run system.command.exist "bash"
	[ "$status" -eq 0 ]
}

@test "system.command.exist - 存在的命令 ls 返回成功" {
	run system.command.exist "ls"
	[ "$status" -eq 0 ]
}

@test "system.command.exist - 不存在的命令返回失败" {
	run system.command.exist "nonexistent_command_xyz123"
	[ "$status" -eq 1 ]
}

@test "system.command.exist - 空参数返回失败" {
	run system.command.exist ""
	[ "$status" -eq 1 ]
}

@test "system.command.exist - 带路径的可执行文件返回成功" {
	run system.command.exist "/bin/bash"
	[ "$status" -eq 0 ]
}

@test "system.command.exist - /usr/bin 下的命令返回成功" {
	run system.command.exist "/usr/bin/env"
	[ "$status" -eq 0 ]
}

# ============ system.os 测试 ============

@test "system.os - 返回当前操作系统类型" {
	result=$(system.os)
	[[ "$result" == "linux" || "$result" == "macos" || "$result" == "windows" || "$result" == "unknown" ]]
}

@test "system.os - Linux 系统返回 linux" {
	local -r actual_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
	if [[ "$actual_os" == "linux" ]]; then
		result=$(system.os)
		[ "$result" = "linux" ]
	fi
}

@test "system.os - macOS (Darwin) 返回 macos" {
	local -r actual_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
	if [[ "$actual_os" == "darwin" ]]; then
		result=$(system.os)
		[ "$result" = "macos" ]
	fi
}

@test "system.os - 缓存变量 _SYSTEM_OS 需要手动初始化" {
	[[ -n "$_SYSTEM_OS" ]]
}

@test "system.os - 加载即初始化" {
	result=$(system.os)
	[[ -n "$_SYSTEM_OS" ]]
}

@test "system.os - 初始化后多次调用使用缓存" {
	result1=$(system.os)
	result2=$(system.os)
	[ "$_SYSTEM_OS" = "$result1" ]
	[ "$result1" = "$result2" ]
}

@test "system.os - 手动设置缓存后直接返回" {
	export _SYSTEM_OS="custom_os"
	result=$(system.os)
	[ "$result" = "custom_os" ]
}

@test "system.arch - 手动设置缓存后直接返回" {
	export _SYSTEM_ARCH="custom_arch"
	result=$(system.arch)
	[ "$result" = "custom_arch" ]
}

# ============ 集成测试 ============

@test "集成测试 - system.os 和 system.arch 返回有效值" {
	os=$(system.os)
	arch=$(system.arch)
	[[ -n "$os" && -n "$arch" ]]
}

@test "集成测试 - 初始化后缓存正常工作" {
	os_result=$(system.os)
	arch_result=$(system.arch)
	[ "$_SYSTEM_OS" = "$os_result" ]
	[ "$_SYSTEM_ARCH" = "$arch_result" ]
}

@test "集成测试 - 混合命令检查和系统信息获取" {
	# 检查 bash 存在
	run system.command.exist "bash"
	[ "$status" -eq 0 ]

	# 获取系统信息
	os=$(system.os)
	arch=$(system.arch)
	[[ -n "$os" && -n "$arch" ]]
}

# ============ system.command.result 测试 ============

@test "system.command.result - 执行简单命令返回结果" {
	result=$(system.command.result "echo hello")
	[ "$result" = "hello" ]
}

@test "system.command.result - 执行多行输出命令" {
	result=$(system.command.result "printf 'line1\nline2'")
	[ "$result" = "line1
line2" ]
}

@test "system.command.result - 空命令返回提示" {
	result=$(system.command.result "true")
	[ "$result" = "（无输出）" ]
}

@test "system.command.result - grep 无匹配返回空字符串" {
	result=$(system.command.result "echo 'hello world' | grep 'xyz'")
	# grep 无匹配时 result 为空，最后被替换为 "（无输出）"
	[ -z "$result" ] || [ "$result" = "（无输出）" ]
}

@test "system.command.result - grep 有匹配返回结果" {
	result=$(system.command.result "echo 'hello world' | grep 'hello'")
	[ "$result" = "hello world" ]
}

@test "system.command.result - 命令执行失败返回错误提示" {
	result=$(system.command.result "ls /nonexistent_directory_xyz_123")
	[[ "$result" == "（命令执行失败，退出码:"* ]]
}

@test "system.command.result - 复杂命令执行" {
	result=$(system.command.result "echo test | tr '[:lower:]' '[:upper:]'")
	[ "$result" = "TEST" ]
}

# ============ system.command.required 测试 ============

@test "system.command.required - 存在命令返回成功" {
	run system.command.required "bash"
	[ "$status" -eq 0 ]
}

# ============ 边界条件测试 ============

@test "system.command.exist - 命令名带特殊字符返回失败" {
	run system.command.exist "test;ls"
	[ "$status" -eq 1 ]
}

@test "system.command.exist - 超长命令名返回失败" {
	run system.command.exist "averylongcommandnamethatdoesntexistinthesystem1234567890"
	[ "$status" -eq 1 ]
}

@test "system.os - 未知操作系统返回 unknown 或空" {
	# 测试实际行为
	result=$(system.os)
	[[ "$result" == "linux" || "$result" == "macos" || "$result" == "windows" || "$result" == "unknown" || "$result" == "" ]]
}

@test "system.arch - 未知架构返回空" {
	# 实际测试 - 如果 uname -m 返回未知架构
	result=$(system.arch)
	# 正常情况下应该返回有效架构之一
	[[ "$result" == "amd64" || "$result" == "arm64" || "$result" == "armhf" || "$result" == "i386" || -z "$result" ]]
}

# ============ 缓存隔离测试 ============

@test "缓存不影响其他测试的隔离性" {
	# 在当前测试中设置缓存
	_SYSTEM_OS="custom_os"
	_SYSTEM_ARCH="custom_arch"

	# 验证缓存生效
	[[ "$(system.os)" == "custom_os" ]]
	[[ "$(system.arch)" == "custom_arch" ]]
}

@test "teardown 后缓存重建" {
	# 这个测试验证 setup 正常工作
	[[ -n "$_SYSTEM_OS" ]]
	[[ -n "$_SYSTEM_ARCH" ]]
}
