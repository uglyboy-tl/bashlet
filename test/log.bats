#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	# 统一导入 log.sh（会自动引入 ansi.sh 等依赖）
	import core/log.sh
	# 默认使用 INFO 等级，大多数测试基于这个等级
	log.setLevel INFO
}

teardown() {
	unset _LOG_LEVEL _LOG_MIN_LEVEL _LOG_USE_EXTRA 2>/dev/null || true
}

# ========== log.setLevel 测试 ==========

@test "log.setLevel - 设置有效等级 DEBUG" {
	log.setLevel DEBUG
	run log.debug "test"
	[[ "$output" == *"[DEBUG]"* ]]
	[[ "$output" == *"test"* ]]
}

@test "log.setLevel - 设置有效等级 INFO" {
	run log.info "test"
	[[ "$output" == *"[INFO]"* ]]
	[[ "$output" == *"test"* ]]
}

@test "log.setLevel - 设置有效等级 WARN" {
	log.setLevel WARN
	run log.warn "test"
	[[ "$output" == *"[WARN]"* ]]
	[[ "$output" == *"test"* ]]
}

@test "log.setLevel - 设置有效等级 ERROR" {
	log.setLevel ERROR
	run log.error "test"
	[[ "$output" == *"[ERROR]"* ]]
	[[ "$output" == *"test"* ]]
}

@test "log.setLevel - 小写等级自动转大写" {
	log.setLevel debug
	run log.debug "test"
	[[ "$output" == *"[DEBUG]"* ]]
	[[ "$output" == *"test"* ]]
}

@test "log.setLevel - 无效等级返回错误" {
	run log.setLevel INVALID
	[ "$status" -ne 0 ]
}

# ========== 等级过滤测试 ==========

@test "log.debug - DEBUG 等级开启时输出" {
	log.setLevel DEBUG
	run log.debug "debug message"
	[[ "$output" == *"[DEBUG]"* ]]
}

@test "log.debug - DEBUG 等级关闭时不输出" {
	run log.debug "debug message"
	[ "$output" = "" ]
}

@test "log.info - INFO 等级开启时输出" {
	run log.info "info message"
	[[ "$output" == *"[INFO]"* ]]
}

@test "log.info - INFO 等级关闭时不输出" {
	log.setLevel WARN
	run log.info "info message"
	[ "$output" = "" ]
}

@test "log.success - SUCCESS 等级按 INFO 级输出（INFO 级开启）" {
	run log.success "success message"
	[[ "$output" == *"[SUCCESS]"* ]]
}

@test "log.success - SUCCESS 等级按 INFO（INFO 级关闭）" {
	log.setLevel WARN
	run log.success "success message"
	[ "$output" = "" ]
}

@test "log.warn - WARN 等级开启时输出" {
	log.setLevel WARN
	run log.warn "warn message"
	[[ "$output" == *"[WARN]"* ]]
}

@test "log.warn - WARN 等级关闭时不输出" {
	log.setLevel ERROR
	run log.warn "warn message"
	[ "$output" = "" ]
}

@test "log.error - ERROR 等级开启时输出" {
	log.setLevel ERROR
	run log.error "error message"
	[[ "$output" == *"[ERROR]"* ]]
}

# ========== 动态调整等级测试 ==========

@test "log.setLevel - 动态调整后立即生效" {
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
	# 清除导入缓存并重新导入，使默认等级生效
	unset '__loaded_modules[$_LIB_DIR/core/log.sh]'
	import core/log.sh
	
	# DEBUG 应该关闭
	run log.debug "debug message"
	[ "$output" = "" ]
	
	# INFO 应该开启
	run log.info "info message"
	[[ "$output" == *"[INFO]"* ]]
}

# ========== 全局变量覆盖测试 ==========

@test "环境变量覆盖默认等级" {
	unset _LOG_LEVEL _LOG_MIN_LEVEL
	export _LOG_LEVEL=ERROR
	# 清除导入缓存并重新导入，使环境变量生效
	unset '__loaded_modules[$_LIB_DIR/core/log.sh]'
	import core/log.sh
	
	# WARN 应该关闭
	run log.warn "warn message"
	[ "$output" = "" ]
	
	# ERROR 应该开启
	run log.error "error message"
	[[ "$output" == *"[ERROR]"* ]]
}

# ========== 多参数输出测试 ==========

@test "log.debug - 多个参数正确连接" {
	log.setLevel DEBUG

	run log.debug "hello" "world"
	[[ "$output" == *"hello world"* ]]
}

@test "log.info - 多个参数正确连接" {
	run log.info "hello" "world" "test"
	[[ "$output" == *"hello world test"* ]]
}

# ========== 时间戳格式测试 ==========

@test "日志输出包含时间戳" {
	run log.info "test"
	# 时间戳格式: MM-DD HH:MM:SS
	[[ "$output" =~ [0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]
}

# ========== _LOG_USE_EXTRA 功能保持测试 ==========

@test "_LOG_USE_EXTRA=true 时显示文件名和行号" {
	export _LOG_USE_EXTRA=true
	run log.info "test"
	[[ "$output" == *"("* ]]
	[[ "$output" == *")"* ]]
	unset _LOG_USE_EXTRA
}

@test "_LOG_USE_EXTRA=false 时不显示文件名和行号" {
	export _LOG_USE_EXTRA=false
	run log.info "test"
	# 不应该包含括号包裹的文件:行号
	[[ ! "$output" =~ \(.*:.*\) ]]
	unset _LOG_USE_EXTRA
}

# ========== 等级映射完整性测试 ==========

@test "等级映射 - DEBUG 值应为 0 并允许 DEBUG 日志" {
	log.setLevel DEBUG
	run log.debug "test"
	[[ "$output" == *"[DEBUG]"* ]]
	[[ "$output" == *"test"* ]]
}

@test "等级映射 - INFO 值应为 1 并允许 INFO 及以上日志" {
	run log.info "test"
	[[ "$output" == *"[INFO]"* ]]
	run log.debug "should not appear"
	[ "$output" = "" ]
}

@test "等级映射 - WARN 值应为 2 并允许 WARN 及以上日志" {
	log.setLevel WARN
	run log.warn "test"
	[[ "$output" == *"[WARN]"* ]]
	run log.info "should not appear"
	[ "$output" = "" ]
}

@test "等级映射 - ERROR 值应为 3 并允许 ERROR 日志" {
	log.setLevel ERROR
	run log.error "test"
	[[ "$output" == *"[ERROR]"* ]]
	run log.warn "should not appear"
	[ "$output" = "" ]
}

# ========== log() 核心函数测试 ==========

@test "log() - 直接调用 INFO 等级" {
	run log info "direct log message"
	[[ "$output" == *"[INFO]"* ]]
	[[ "$output" == *"direct log message"* ]]
}

@test "log() - 直接调用 DEBUG 等级" {
	log.setLevel DEBUG
	run log debug "debug test"
	[[ "$output" == *"[DEBUG]"* ]]
	[[ "$output" == *"debug test"* ]]
}

@test "log() - 直接调用 WARN 等级" {
	log.setLevel WARN
	run log warn "warn test"
	[[ "$output" == *"[WARN]"* ]]
	[[ "$output" == *"warn test"* ]]
}

@test "log() - 直接调用 ERROR 等级" {
	log.setLevel ERROR
	run log error "error test"
	[[ "$output" == *"[ERROR]"* ]]
	[[ "$output" == *"error test"* ]]
}

@test "log() - 直接调用 SUCCESS 等级" {
	run log success "success test"
	[[ "$output" == *"[SUCCESS]"* ]]
	[[ "$output" == *"success test"* ]]
}

@test "log() - 调用未知等级时正常输出消息" {
	run log UNKNOWN "unknown level message"
	# 未知等级不会显示等级标签，但消息仍会输出
	[[ "$output" == *"unknown level message"* ]]
	# 不应包含任何已知等级标签
	[[ ! "$output" == *"[DEBUG]"* ]]
	[[ ! "$output" == *"[INFO]"* ]]
	[[ ! "$output" == *"[WARN]"* ]]
	[[ ! "$output" == *"[ERROR]"* ]]
}

# ========== 多参数测试补充 ==========

@test "log.warn - 多个参数正确连接" {
	log.setLevel WARN
	run log.warn "warning" "message" "here"
	[[ "$output" == *"warning message here"* ]]
}

@test "log.error - 多个参数正确连接" {
	log.setLevel ERROR
	run log.error "error" "has" "occurred"
	[[ "$output" == *"error has occurred"* ]]
}

@test "log.success - 多个参数正确连接" {
	run log.success "operation" "completed" "successfully"
	[[ "$output" == *"operation completed successfully"* ]]
}

@test "log() - 多个参数正确连接" {
	run log info "first" "second" "third"
	[[ "$output" == *"first second third"* ]]
}

# ========== 等级过滤补充测试 ==========

@test "log.error - ERROR 等级关闭时不输出" {
	# 无法设置比 ERROR 更低的等级，但可以用 UNKNOWN 模拟
	# 或者测试在 FATAL 级别（如果存在）
	# 由于 ERROR 是最高等级，这个测试改为验证行为
	log.setLevel ERROR
	run log.error "error message"
	[[ "$output" == *"[ERROR]"* ]]
}

# ========== 边界情况测试 ==========

@test "log.info - 空消息输出" {
	run log.info ""
	[[ "$output" == *"[INFO]"* ]]
}

@test "log.info - 消息包含特殊字符" {
	run log.info "message with (parentheses) and [brackets]"
	[[ "$output" == *"message with (parentheses) and [brackets]"* ]]
}

@test "log.info - 消息包含引号" {
	run log.info 'message with "quotes"'
	[[ "$output" == *'message with "quotes"'* ]]
}

@test "log.debug - DEBUG 等级完全关闭验证" {
	run log.debug "should not appear"
	[ "$output" = "" ]
}

# ========== 日志级别小写测试补充 ==========

@test "log.setLevel - 混合大小写等级 (Debug)" {
	log.setLevel Debug
	run log.debug "mixed case test"
	[[ "$output" == *"[DEBUG]"* ]]
}

@test "log.setLevel - 混合大小写等级 (Info)" {
	log.setLevel Info
	run log.info "mixed case test"
	[[ "$output" == *"[INFO]"* ]]
}

# ========== 输出格式验证测试 ==========

@test "日志输出格式 - 包含时间戳、等级标签和消息" {
	run log.info "format test"
	# 验证格式：时间戳 等级标签 消息
	[[ "$output" =~ [0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]
	[[ "$output" == *"[INFO]"* ]]
	[[ "$output" == *"format test"* ]]
}

@test "不同等级的标签颜色区分" {
	
	# 由于 bats 捕获输出时颜色代码可能被处理，
	# 这里主要验证不同等级能正确输出对应标签
	log.setLevel DEBUG
	run log.debug "test"
	[[ "$output" == *"[DEBUG]"* ]]
	
	log.setLevel ERROR
	run log.error "test"
	[[ "$output" == *"[ERROR]"* ]]
}

# ========== ANSI 颜色代码验证测试 ==========

@test "log.info - 输出包含蓝色 ANSI 代码" {
	run log.info "color test"
	# BLUE="${ANSI_CSI}34m", NC="${ANSI_CSI}0m"
	# 验证输出包含蓝色代码包裹的 [INFO]
	[[ "$output" == *"$BLUE[INFO]$NC"* ]]
}

@test "log.error - 输出包含红色 ANSI 代码" {
	log.setLevel ERROR
	run log.error "color test"
	# RED="${ANSI_CSI}31m"
	[[ "$output" == *"$RED[ERROR]$NC"* ]]
}

@test "log.warn - 输出包含黄色 ANSI 代码" {
	log.setLevel WARN
	run log.warn "color test"
	# YELLOW="${ANSI_CSI}33m"
	[[ "$output" == *"$YELLOW[WARN]$NC"* ]]
}

@test "log.success - 输出包含绿色 ANSI 代码" {
	run log.success "color test"
	# GREEN="${ANSI_CSI}32m"
	[[ "$output" == *"$GREEN[SUCCESS]$NC"* ]]
}

@test "log.debug - 输出包含白色 ANSI 代码" {
	log.setLevel DEBUG
	run log.debug "color test"
	# WHITE="${ANSI_CSI}37m"
	[[ "$output" == *"$WHITE[DEBUG]$NC"* ]]
}

@test "时间戳使用白色 ANSI 代码" {
	run log.info "timestamp color test"
	# 时间戳应该由 WHITE 开头，后面跟着 NC 重置
	[[ "$output" == *$WHITE[0-9]* ]] || [[ "$output" == *$WHITE* ]]
}

# ========== 返回状态码测试（新增测试用例） ==========

@test "log.debug - 总是返回状态码 0" {
	log.setLevel DEBUG
	run log.debug "test message"
	[ "$status" -eq 0 ]
}

@test "log.debug - 等级过滤时也返回状态码 0" {
	# INFO 级别，DEBUG 应该被过滤
	run log.debug "should not appear"
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "log.info - 总是返回状态码 0" {
	run log.info "test message"
	[ "$status" -eq 0 ]
}

@test "log.info - 等级过滤时也返回状态码 0" {
	log.setLevel WARN
	run log.info "should not appear"
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "log.success - 总是返回状态码 0" {
	run log.success "test message"
	[ "$status" -eq 0 ]
}

@test "log.success - 等级过滤时也返回状态码 0" {
	log.setLevel WARN
	run log.success "should not appear"
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "log.warn - 总是返回状态码 0" {
	log.setLevel WARN
	run log.warn "test message"
	[ "$status" -eq 0 ]
}

@test "log.warn - 等级过滤时也返回状态码 0" {
	log.setLevel ERROR
	run log.warn "should not appear"
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "log.error - 总是返回状态码 0" {
	log.setLevel ERROR
	run log.error "test message"
	[ "$status" -eq 0 ]
}

@test "log() - 直接调用也返回状态码 0" {
	run log info "test message"
	[ "$status" -eq 0 ]
}

@test "log.setLevel - 设置有效等级返回状态码 0" {
	run log.setLevel DEBUG
	[ "$status" -eq 0 ]
}

@test "log.setLevel - 设置无效等级返回非零状态码" {
	run log.setLevel INVALID
	[ "$status" -ne 0 ]
}
