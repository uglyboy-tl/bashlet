#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	# 不在这里导入 log.sh，让每个测试自己处理
}

teardown() {
	unset _LOG_LEVEL _LOG_MIN_LEVEL _LOG_USE_EXTRA 2>/dev/null || true
}

# ========== log.setLevel 测试 ==========

@test "log.setLevel - 设置有效等级 DEBUG" {
	import core/log.sh
	log.setLevel DEBUG
	run log.debug "test"
	[[ "$output" != "" ]]
}

@test "log.setLevel - 设置有效等级 INFO" {
	import core/log.sh
	log.setLevel INFO
	run log.info "test"
	[[ "$output" != "" ]]
}

@test "log.setLevel - 设置有效等级 WARN" {
	import core/log.sh
	log.setLevel WARN
	run log.warn "test"
	[[ "$output" != "" ]]
}

@test "log.setLevel - 设置有效等级 ERROR" {
	import core/log.sh
	log.setLevel ERROR
	run log.error "test"
	[[ "$output" != "" ]]
}

@test "log.setLevel - 小写等级自动转大写" {
	import core/log.sh
	log.setLevel debug
	run log.debug "test"
	[[ "$output" != "" ]]
}

@test "log.setLevel - 无效等级返回错误" {
	import core/log.sh
	run log.setLevel INVALID
	[ "$status" -ne 0 ]
}

# ========== 等级过滤测试 ==========

@test "log.debug - DEBUG 等级开启时输出" {
	import core/log.sh
	log.setLevel DEBUG
	run log.debug "debug message"
	[[ "$output" == *"[DEBUG]"* ]]
}

@test "log.debug - DEBUG 等级关闭时不输出" {
	import core/log.sh
	log.setLevel INFO
	run log.debug "debug message"
	[ "$output" = "" ]
}

@test "log.info - INFO 等级开启时输出" {
	import core/log.sh
	log.setLevel INFO
	run log.info "info message"
	[[ "$output" == *"[INFO]"* ]]
}

@test "log.info - INFO 等级关闭时不输出" {
	import core/log.sh
	log.setLevel WARN
	run log.info "info message"
	[ "$output" = "" ]
}

@test "log.success - SUCCESS 等级按 INFO 级输出（INFO 级开启）" {
	import core/log.sh
	log.setLevel INFO
	run log.success "success message"
	[[ "$output" == *"[SUCCESS]"* ]]
}

@test "log.success - SUCCESS 等级按 INFO（INFO 级关闭）" {
	import core/log.sh
	log.setLevel WARN
	run log.success "success message"
	[ "$output" = "" ]
}

@test "log.warn - WARN 等级开启时输出" {
	import core/log.sh
	log.setLevel WARN
	run log.warn "warn message"
	[[ "$output" == *"[WARN]"* ]]
}

@test "log.warn - WARN 等级关闭时不输出" {
	import core/log.sh
	log.setLevel ERROR
	run log.warn "warn message"
	[ "$output" = "" ]
}

@test "log.error - ERROR 等级开启时输出" {
	import core/log.sh
	log.setLevel ERROR
	run log.error "error message"
	[[ "$output" == *"[ERROR]"* ]]
}

# ========== 动态调整等级测试 ==========

@test "log.setLevel - 动态调整后立即生效" {
	import core/log.sh
	# 设置 ERROR 级
	log.setLevel ERROR
	
	# ERROR 级开启
	run log.error "error message"
	[[ "$output" != "" ]]
	
	# INFO 级关闭
	run log.info "info message"
	[ "$output" = "" ]
	
	# 调整到 DEBUG 级
	log.setLevel DEBUG
	
	# INFO 现在应该输出
	run log.info "info message"
	[[ "$output" != "" ]]
}

# ========== 默认等级测试 ==========

@test "默认等级为 INFO" {
	unset _LOG_LEVEL _LOG_MIN_LEVEL
	import core/log.sh
	
	# DEBUG 应该关闭
	run log.debug "debug message"
	[ "$output" = "" ]
	
	# INFO 应该开启
	run log.info "info message"
	[[ "$output" != "" ]]
}

# ========== 全局变量覆盖测试 ==========

@test "环境变量覆盖默认等级" {
	unset _LOG_LEVEL _LOG_MIN_LEVEL
	export _LOG_LEVEL=ERROR
	import core/log.sh
	
	# WARN 应该关闭
	run log.warn "warn message"
	[ "$output" = "" ]
	
	# ERROR 应该开启
	run log.error "error message"
	[[ "$output" != "" ]]
}

# ========== 多参数输出测试 ==========

@test "log.debug - 多个参数正确连接" {
	import core/log.sh
	log.setLevel DEBUG

	run log.debug "hello" "world"
	[[ "$output" == *"hello world"* ]]
}

@test "log.info - 多个参数正确连接" {
	import core/log.sh
	log.setLevel INFO
	run log.info "hello" "world" "test"
	[[ "$output" == *"hello world test"* ]]
}

# ========== 时间戳格式测试 ==========

@test "日志输出包含时间戳" {
	import core/log.sh
	log.setLevel INFO
	run log.info "test"
	# 时间戳格式: MM-DD HH:MM:SS
	[[ "$output" =~ [0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]
}

# ========== _LOG_USE_EXTRA 功能保持测试 ==========

@test "_LOG_USE_EXTRA=true 时显示文件名和行号" {
	import core/log.sh
	log.setLevel INFO
	export _LOG_USE_EXTRA=true
	run log.info "test"
	[[ "$output" == *"("* ]]
	[[ "$output" == *")"* ]]
	unset _LOG_USE_EXTRA
}

@test "_LOG_USE_EXTRA=false 时不显示文件名和行号" {
	import core/log.sh
	log.setLevel INFO
	export _LOG_USE_EXTRA=false
	run log.info "test"
	# 不应该包含括号包裹的文件:行号
	[[ ! "$output" =~ \(.*:.*\) ]]
	unset _LOG_USE_EXTRA
}

# ========== 等级映射完整性测试 ==========

@test "所有等级对应的数值正确" {
	import core/log.sh
	
	log.setLevel DEBUG
	run log.debug "test"
	[[ "$output" != "" ]]
	
	log.setLevel INFO
	run log.info "test"
	[[ "$output" != "" ]]
	
	log.setLevel WARN
	run log.warn "test"
	[[ "$output" != "" ]]
	
	log.setLevel ERROR
	run log.error "test"
	[[ "$output" != "" ]]
}
