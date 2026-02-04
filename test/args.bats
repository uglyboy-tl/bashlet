#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import core/args
	unset _ARGS_OPTS _ARGS_ARGS _ARGS_OPT_ARGS 2>/dev/null || true
}

teardown() {
	unset _ARGS_OPTS _ARGS_ARGS _ARGS_OPT_ARGS _ARGS_OPTIONS _ARGS_OPTIONS_SWITCH _ARGS_OPTIONS_TYPE _ARGS_HELP_OPTIONS _ARGS_HELP_ARGS _ARGS_HELP_EXAMPLES _ARGS_HELP_NOTICES 2>/dev/null || true
	_ARGS_CURRENT_SUBCOMMAND=""
}

# ============ args.get 测试 ============

@test "args.get - 获取短选项的参数值" {
	args.parse -f filename.txt
	result=$(args.get "-f")
	[ "$result" = "filename.txt" ]
}

@test "args.get - 获取长选项的参数值" {
	args.parse --file filename.txt
	result=$(args.get "--file")
	[ "$result" = "filename.txt" ]
}

@test "args.get - 选项无参数值时返回错误" {
	args.parse -v
	run args.get "-v"
	[ "$status" -ne 0 ]
}

@test "args.get - 选项不存在时返回错误" {
	args.parse -f filename.txt
	run args.get "-x"
	[ "$status" -ne 0 ]
}

# ============ args.count 测试 ============

@test "args.count - 统计三个位置参数" {
	args.parse arg1 arg2 arg3
	result=$(args.count)
	[ "$result" = "3" ]
}

@test "args.count - 统计选项参数值作为位置参数" {
	args.parse -v -f file.txt
	result=$(args.count)
	[ "$result" = "1" ]
}

@test "args.count - 无参数时返回 0" {
	args.parse
	result=$(args.count)
	[ "$result" = "0" ]
}

# ============ args.arg 测试 ============

@test "args.arg - 通过索引获取第一个位置参数" {
	args.parse arg1 arg2 arg3
	result=$(args.arg 0)
	[ "$result" = "arg1" ]
}

@test "args.arg - 通过索引获取第二个位置参数" {
	args.parse arg1 arg2 arg3
	result=$(args.arg 1)
	[ "$result" = "arg2" ]
}

@test "args.arg - 索引越界时返回错误" {
	args.parse arg1 arg2
	run args.arg 5
	[ "$status" -ne 0 ]
}

@test "args.arg - 无位置参数时返回错误" {
	args.parse -v
	run args.arg 0
	[ "$status" -ne 0 ]
}

@test "args.arg - 可访问作为位置参数的选项参数值" {
	args.parse -v -f file.txt
	result=$(args.arg 0)
	[ "$result" = "file.txt" ]
}

# ============ args.has 测试 ============

@test "args.has - 检查存在的短选项" {
	args.parse -v -f file.txt
	run args.has "-v"
	[ "$status" -eq 0 ]
}

@test "args.has - 检查存在的长选项" {
	args.parse --verbose --output result.txt
	run args.has "--verbose"
	[ "$status" -eq 0 ]
}

@test "args.has - 检查不存在的选项" {
	args.parse -v -f file.txt
	run args.has "-x"
	[ "$status" -eq 1 ]
}

@test "args.has - 检查带参数值的选项" {
	args.parse -f filename.txt --output result.txt
	run args.has "-f"
	[ "$status" -eq 0 ]
	run args.has "--output"
	[ "$status" -eq 0 ]
}

@test "args.has - 多参数时匹配第一个存在" {
	args.parse -v -f file.txt
	run args.has "-v" "--verbose"
	[ "$status" -eq 0 ]
}

@test "args.has - 多参数时匹配第二个存在" {
	args.parse --verbose -f file.txt
	run args.has "-v" "--verbose"
	[ "$status" -eq 0 ]
}

@test "args.has - 多参数时全部不存在" {
	args.parse -f file.txt
	run args.has "-v" "--verbose"
	[ "$status" -eq 1 ]
}

@test "args.has - 混合长短选项时匹配" {
	args.parse -v --output result.txt
	run args.has "--verbose" "-v"
	[ "$status" -eq 0 ]
}

@test "args.has - 三个以上参数时匹配失败" {
	args.parse --output result.txt
	run args.has "-v" "--verbose" "-q" "--quiet"
	[ "$status" -eq 1 ]
}

@test "args.has - 空参数时返回失败" {
	args.parse -v
	run args.has
	[ "$status" -eq 1 ]
}

# ============ args.parse 测试 ============

@test "args.parse - 混合短选项和长选项" {
	args.parse -v --verbose -f
	[ "${_ARGS_OPTS[0]}" = "-v" ]
	[ "${_ARGS_OPTS[1]}" = "--verbose" ]
	[ "${_ARGS_OPTS[2]}" = "-f" ]
	[ ${#_ARGS_OPTS[@]} -eq 3 ]
	[ ${#_ARGS_ARGS[@]} -eq 0 ]
	[ ${#_ARGS_OPT_ARGS[@]} -eq 0 ]
}

@test "args.parse - 仅位置参数" {
	args.parse file1.txt file2.txt file3.txt
	[ ${#_ARGS_OPTS[@]} -eq 0 ]
	[ "${_ARGS_ARGS[0]}" = "file1.txt" ]
	[ "${_ARGS_ARGS[1]}" = "file2.txt" ]
	[ "${_ARGS_ARGS[2]}" = "file3.txt" ]
	[ ${#_ARGS_ARGS[@]} -eq 3 ]
	[ ${#_ARGS_OPT_ARGS[@]} -eq 0 ]
}

@test "args.parse - 选项和位置参数混合" {
	args.parse -v --output file1.txt arg2.txt
	[ "${_ARGS_OPTS[0]}" = "-v" ]
	[ "${_ARGS_OPTS[1]}" = "--output" ]
	[ ${#_ARGS_OPTS[@]} -eq 2 ]
	[ "${_ARGS_ARGS[0]}" = "file1.txt" ]
	[ "${_ARGS_ARGS[1]}" = "arg2.txt" ]
	[ ${#_ARGS_ARGS[@]} -eq 2 ]
	[ "$(args.get "--output")" = "file1.txt" ]
	[ ${#_ARGS_OPT_ARGS[@]} -eq 1 ]
}

@test "args.parse - 带参数值的多个选项" {
	args.parse -f filename.txt --output result.txt -v
	[ "${_ARGS_OPTS[0]}" = "-f" ]
	[ "${_ARGS_OPTS[1]}" = "--output" ]
	[ "${_ARGS_OPTS[2]}" = "-v" ]
	[ ${#_ARGS_OPTS[@]} -eq 3 ]
	[ "${_ARGS_ARGS[0]}" = "filename.txt" ]
	[ "${_ARGS_ARGS[1]}" = "result.txt" ]
	[ ${#_ARGS_ARGS[@]} -eq 2 ]
	[ "$(args.get "-f")" = "filename.txt" ]
	[ "$(args.get "--output")" = "result.txt" ]
	[ ${#_ARGS_OPT_ARGS[@]} -eq 2 ]
}

@test "args.parse - 正确处理 -- 分隔符" {
	args.parse -v --output file.txt -- arg1.txt -f arg2.txt
	[ "${_ARGS_OPTS[0]}" = "-v" ]
	[ "${_ARGS_OPTS[1]}" = "--output" ]
	[ ${#_ARGS_OPTS[@]} -eq 2 ]
	[ "${_ARGS_ARGS[0]}" = "file.txt" ]
	[ "${_ARGS_ARGS[1]}" = "arg1.txt" ]
	[ "${_ARGS_ARGS[2]}" = "-f" ]
	[ "${_ARGS_ARGS[3]}" = "arg2.txt" ]
	[ $(args.count) -eq 4 ]
	[ "$(args.get "--output")" = "file.txt" ]
	[ ${#_ARGS_OPT_ARGS[@]} -eq 1 ]
}

@test "args.parse - 空参数列表" {
	args.parse
	[ ${#_ARGS_OPTS[@]} -eq 0 ]
	[ ${#_ARGS_ARGS[@]} -eq 0 ]
}

@test "args.parse - 特殊字符参数值" {
	args.parse -f "file with spaces.txt" --key "value\$VAR"
	[ "$(args.get "-f")" = "file with spaces.txt" ]
	[ "$(args.get "--key")" = 'value$VAR' ]
}

# ============ args.parse 测试（组合参数） ============

@test "args.parse - 将 -vab 分解为 -v -a -b" {
	args.parse -vab
	[ "${_ARGS_OPTS[0]}" = "-v" ]
	[ "${_ARGS_OPTS[1]}" = "-a" ]
	[ "${_ARGS_OPTS[2]}" = "-b" ]
	[ ${#_ARGS_OPTS[@]} -eq 3 ]
	run args.has "-v"
	[ "$status" -eq 0 ]
	run args.has "-a"
	[ "$status" -eq 0 ]
	run args.has "-b"
	[ "$status" -eq 0 ]
	[ $(args.count) -eq 0 ]
}

@test "args.parse - 混合组合参数和普通参数" {
	args.parse -xv --force file.txt
	[ "${_ARGS_OPTS[0]}" = "-x" ]
	[ "${_ARGS_OPTS[1]}" = "-v" ]
	[ "${_ARGS_OPTS[2]}" = "--force" ]
	[ ${#_ARGS_OPTS[@]} -eq 3 ]
}

@test "args.parse - 多个连续的组合参数" {
	args.parse -vab -cde file.txt
	[ "${_ARGS_OPTS[0]}" = "-v" ]
	[ "${_ARGS_OPTS[1]}" = "-a" ]
	[ "${_ARGS_OPTS[2]}" = "-b" ]
	[ "${_ARGS_OPTS[3]}" = "-c" ]
	[ "${_ARGS_OPTS[4]}" = "-d" ]
	[ "${_ARGS_OPTS[5]}" = "-e" ]
	[ ${#_ARGS_OPTS[@]} -eq 6 ]
	[ "${_ARGS_ARGS[0]}" = "file.txt" ]
	[ $(args.count) -eq 1 ]
}

@test "args.parse - 组合参数后存储选项参数值" {
	args.parse -vf file.txt
	[ "${_ARGS_OPTS[0]}" = "-v" ]
	[ "${_ARGS_OPTS[1]}" = "-f" ]
	[ ${#_ARGS_OPTS[@]} -eq 2 ]
	run args.has "-v"
	[ "$status" -eq 0 ]
	run args.has "-f"
	[ "$status" -eq 0 ]
	[ "${_ARGS_ARGS[0]}" = "file.txt" ]
	[ $(args.count) -eq 1 ]
	[ ${#_ARGS_OPT_ARGS[@]} -eq 1 ]
	run args.get "-v"
	[ "$status" -ne 0 ]
	run args.get "-f"
	[ "$status" -eq 0 ]
}

# ============ 集成测试（多函数协作） ============

@test "集成测试 - args.parse + args.has + args.get + args.count 典型场景" {
	args.parse -v -f input.txt --output output.txt
	run args.has "-v"
	[ "$status" -eq 0 ]
	[ "$(args.get "-f")" = "input.txt" ]
	[ "$(args.get "--output")" = "output.txt" ]
	[ "${_ARGS_ARGS[0]}" = "input.txt" ]
	[ "${_ARGS_ARGS[1]}" = "output.txt" ]
	[ $(args.count) -eq 2 ]
}

@test "集成测试 - args.parse + args.has 处理 -- 分隔符" {
	args.parse -v file1.txt -- -f file2.txt
	run args.has "-v"
	[ "$status" -eq 0 ]
	[ "${_ARGS_ARGS[0]}" = "file1.txt" ]
	[ "${_ARGS_ARGS[1]}" = "-f" ]
	[ "${_ARGS_ARGS[2]}" = "file2.txt" ]
}

@test "集成测试 - args.parse + args.has + args.get 多个混合选项和参数" {
	args.parse -a -b --long1 val1 -c --long2 val2
	run args.has "-a"
	[ "$status" -eq 0 ]
	run args.has "-b"
	[ "$status" -eq 0 ]
	run args.has "-c"
	[ "$status" -eq 0 ]
	run args.has "--long1"
	[ "$status" -eq 0 ]
	run args.has "--long2"
	[ "$status" -eq 0 ]
	[ "$(args.get "--long1")" = "val1" ]
	[ "$(args.get "--long2")" = "val2" ]
	[ "${_ARGS_ARGS[0]}" = "val1" ]
	[ "${_ARGS_ARGS[1]}" = "val2" ]
	[ $(args.count) -eq 2 ]
}

# ============ args.verify 测试 ============

setup_verify() {
	unset _ARGS_OPTIONS _ARGS_OPTIONS_SWITCH _ARGS_OPTIONS_TYPE 2>/dev/null || true
	args.init
	args.add_options "verbose" "v" "显示详细输出"
	args.add_options "file" "f" "指定输入文件" "FILE"
	args.add_options "output" "o" "指定输出文件" "FILE"
	args.add_options "quiet" "q" "安静模式"
	args.add_options "arg" "a" "安静模式"
}

@test "args.verify - 已注册选项验证通过" {
	setup_verify
	args.parse -v -f input.txt
	args.verify
	[ $? -eq 0 ]
}

@test "args.verify - 未注册选项验证失败" {
	setup_verify
	args.parse -x input.txt
	run args.verify
	[ "$status" -ne 0 ]
}

@test "args.verify - 多个未注册选项失败" {
	setup_verify
	args.parse -x -y input.txt
	run args.verify
	[ "$status" -ne 0 ]
}

@test "args.verify - 重复短选项检测" {
	setup_verify
	args.parse -v -v
	run args.verify
	[ "$status" -ne 0 ]
}

@test "args.verify - 重复长选项检测" {
	setup_verify
	args.parse --verbose --verbose
	run args.verify
	[ "$status" -ne 0 ]
}

@test "args.verify - 短选项和长选项互斥检测" {
	setup_verify
	args.parse -v --verbose
	run args.verify
	[ "$status" -ne 0 ]
}

@test "args.verify - 不同选项可以重复使用" {
	setup_verify
	args.parse -v -f file.txt -q -o output.txt
	args.verify
	[ $? -eq 0 ]
}

@test "args.verify - 需要参数的选项未提供参数失败" {
	setup_verify
	args.parse -f
	run args.verify
	[ "$status" -ne 0 ]
}

@test "args.verify - 需要参数的选项提供参数通过" {
	setup_verify
	args.parse -f input.txt
	args.verify
	[ $? -eq 0 ]
}

@test "args.verify - 不需要参数的选项有参数也通过" {
	setup_verify
	args.add_options "flag" "" "标志" "NONE"
	args.parse --flag extra
	run args.verify
	[ "$status" -eq 0 ]
}

@test "args.verify - 组合参数验证通过" {
	setup_verify
	args.parse -vqf input.txt
	args.verify
	[ $? -eq 0 ]
}

@test "args.verify - 组合参数包含未注册选项失败" {
	setup_verify
	args.parse -vx input.txt
	run args.verify
	[ "$status" -ne 0 ]
}

@test "args.verify - 混合短长选项验证通过" {
	setup_verify
	args.parse --verbose -f input.txt --output result.txt
	args.verify
	[ $? -eq 0 ]
}

@test "args.verify - -- 分隔符后参数不验证" {
	setup_verify
	args.parse -v -- input.txt -x
	args.verify
	[ $? -eq 0 ]
}


# ============ args.verify 位置参数验证测试 ============

@test "args.verify - 未注册参数但有位置参数时失败" {
	args.init
	# 不注册任何 ARG，但提供位置参数
	args.parse arg1 arg2
	run args.verify
	[ "$status" -ne 0 ]
}

@test "args.verify - 注册参数后有位置参数时通过" {
	args.init
	args.add_options "ARG" "input" "输入文件"
	args.parse input.txt
	args.verify
	[ $? -eq 0 ]
}

@test "args.verify - 无注册参数也无位置参数时通过" {
	args.init
	args.parse
	args.verify
	[ $? -eq 0 ]
}

# ============ args.name / args.description 测试 ============

@test "args.name - 设置显示名称" {
	args.name "myscript"
	[ "$_SCRIPT_DISPLAY" = "myscript" ]
}

@test "args.description - 设置脚本描述" {
	args.description "A test script"
	[ "$_SCRIPT_DESC" = "A test script" ]
}

@test "args.description - 空参数时返回失败不修改描述" {
	_SCRIPT_DESC="existing"
	run args.description ""
	[ "$_SCRIPT_DESC" = "existing" ]
	[ "$status" -ne 0 ]
}

# ============ args.init 测试 ============

@test "args.init - 创建选项组并设置当前选项" {
	args.init
	[ "${#_ARGS_OPTIONS[@]}" -eq 2 ]  # 默认添加了 help 和 h 选项
	[ "${_ARGS_OPTIONS[0]}" = "help" ]
	[ "${_ARGS_OPTIONS[1]}" = "h" ]
}

@test "args.init - 多次调用会清空之前选项" {
	args.init
	args.add_options "verbose" "v" "显示详细输出"
	[ "${#_ARGS_OPTIONS[@]}" -eq 4 ]  # help, h, verbose, v
	args.init
	[ "${#_ARGS_OPTIONS[@]}" -eq 2 ]  # 重新初始化后只有 help 和 h
}

@test "args.init - 带描述参数时设置描述" {
	args.init "测试描述"
	[ "$_SCRIPT_DESC" = "测试描述" ]
	[ "${#_ARGS_OPTIONS[@]}" -eq 2 ]  # 仍然有 help 选项
}

@test "args.init - 不带参数时不设置描述" {
	unset _SCRIPT_DESC 2>/dev/null || true
	args.init
	[ -z "$_SCRIPT_DESC" ]
}

# ============ args.add_options 测试 ============

@test "args.add_options - 添加选项" {
	args.init
	args.add_options "verbose" "v" "显示详细输出"
	[ "${_ARGS_OPTIONS[2]}" = "verbose" ]
	[ "${_ARGS_OPTIONS[3]}" = "v" ]
}

@test "args.add_options - 添加带类型选项" {
	args.init
	args.add_options "file" "f" "输入文件" "FILE"
	[ "${_ARGS_OPTIONS_TYPE[file]}" = "FILE" ]
}

@test "args.add_options - 添加 ARG 参数" {
	args.init
	args.add_options "ARG" "input" "输入文件"
	[ "${_ARGS_HELP_ARGS[input]}" = "输入文件" ]
}

@test "args.add_options - 添加 EXAMPLE 示例" {
	args.init
	args.add_options "EXAMPLE" "command" "示例说明"
	# 示例会包含脚本名，验证映射不为空
	[ ${#_ARGS_HELP_EXAMPLES[@]} -gt 0 ]
}

@test "args.add_options - 添加 NOTICE 通知" {
	args.init
	args.add_options "NOTICE" "注意：此选项需要管理员权限"
	# NOTICE 使用数组追加，验证数组不为空
	[ ${#_ARGS_HELP_NOTICES[@]} -gt 0 ]
}

# ============ args.add_subcommand 测试 ============

@test "args.add_subcommand - 函数存在但不执行任何操作" {
	args.add_subcommand "build" "构建项目" "build_handler"
	# 验证子命令已注册
	[[ -v "_ARGS_SUBCOMMANDS[build]" ]]
	[ "${_ARGS_SUBCOMMANDS[build]}" = "build_handler" ]
	[ "${_ARGS_SUBCOMMANDS_DESC[build]}" = "构建项目" ]
}

@test "args.dispatch - 调用已注册子命令" {
	args.add_subcommand "test" "测试命令" "test_cmd_handler"
	test_cmd_handler() { echo "handler_called:$1:$2"; }
	result=$(args.dispatch test arg1 arg2)
	[ "$result" = "handler_called:arg1:arg2" ]
}

@test "args.dispatch - 子命令不存在返回错误" {
	args.add_subcommand "build" "构建" "build_handler"
	args.dispatch "notexist" 2>/dev/null || true
	! args.dispatch "notexist" 2>/dev/null
}

@test "args.dispatch - 空参数返回错误" {
	args.add_subcommand "deploy" "部署" "deploy_handler"
	! args.dispatch "" 2>/dev/null
}

@test "args.add_subcommand - 注册多个子命令" {
	args.add_subcommand "build" "构建项目" "build_handler"
	args.add_subcommand "test" "运行测试" "test_handler"
	args.add_subcommand "deploy" "部署应用" "deploy_handler"
	[ ${#_ARGS_SUBCOMMANDS[@]} -eq 3 ]
	[ "${_ARGS_SUBCOMMANDS_DESC[build]}" = "构建项目" ]
	[ "${_ARGS_SUBCOMMANDS_DESC[test]}" = "运行测试" ]
	[ "${_ARGS_SUBCOMMANDS_DESC[deploy]}" = "部署应用" ]
	[ "${_ARGS_SUBCOMMANDS[build]}" = "build_handler" ]
	[ "${_ARGS_SUBCOMMANDS[test]}" = "test_handler" ]
	[ "${_ARGS_SUBCOMMANDS[deploy]}" = "deploy_handler" ]
}

@test "args.dispatch - 多个子命令调用正确 handler" {
	args.add_subcommand "foo" "FOO命令" "foo_handler"
	args.add_subcommand "bar" "BAR命令" "bar_handler"
	foo_handler() { echo "foo:$1"; }
	bar_handler() { echo "bar:$1"; }
	result1=$(args.dispatch foo arg1)
	result2=$(args.dispatch bar arg2)
	[ "$result1" = "foo:arg1" ]
	[ "$result2" = "bar:arg2" ]
}

@test "args.add_subcommand - 子命令中再次添加不生效" {
	# 模拟在子命令处理器中再次调用 add_subcommand
	# 应当返回 0 而不修改任何数据
	_ARGS_CURRENT_SUBCOMMAND="existing"
	original_count=${#_ARGS_SUBCOMMANDS[@]}
	args.add_subcommand "newcmd" "新命令" "new_handler"
	[ ${#_ARGS_SUBCOMMANDS[@]} -eq $original_count ]
}

# ============ args.process 测试 ============

@test "args.process - 无子命令时解析并验证参数" {
	local tmp_script="/tmp/test_process_$$.sh"
	cat > "$tmp_script" << 'SCRIPT'
#!/usr/bin/env bash
PROJECT_ROOT="/home/uglyboy/Code/bashlet"
source "$PROJECT_ROOT/src/std/import.sh"
import core/args
args.init "测试脚本"
args.add_options "file" "f" "输入文件" "FILE"
args.process -f test.txt
echo "success"
SCRIPT
	run bash "$tmp_script"
	rm -f "$tmp_script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"success"* ]]
}

@test "args.process - 显示帮助时退出状态为0" {
	local tmp_script="/tmp/test_help_$$.sh"
	cat > "$tmp_script" << 'SCRIPT'
#!/usr/bin/env bash
PROJECT_ROOT="/home/uglyboy/Code/bashlet"
source "$PROJECT_ROOT/src/std/import.sh"
import core/args
args.init "测试脚本"
args.add_options "file" "f" "输入文件" "FILE"
args.process --help
echo "after help"
SCRIPT
	run bash "$tmp_script"
	rm -f "$tmp_script"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" != *"after help"* ]]
}

@test "args.process - 验证失败时显示帮助并退出" {
	local tmp_script="/tmp/test_verify_fail_$$.sh"
	cat > "$tmp_script" << 'SCRIPT'
#!/usr/bin/env bash
PROJECT_ROOT="/home/uglyboy/Code/bashlet"
source "$PROJECT_ROOT/src/std/import.sh"
import core/args
args.init
args.add_options "file" "f" "输入文件" "FILE"
args.process -f
echo "should not reach"
SCRIPT
	run bash "$tmp_script"
	rm -f "$tmp_script"
	[ "$status" -eq 1 ]
	[[ "$output" != *"should not reach"* ]]
}

# ============ 辅助函数测试 ============

@test "args.opt_index - 返回选项的参数索引" {
	args.parse -f file.txt
	result=$(args.opt_index "-f")
	[ "$result" = "0" ]
}

@test "args.opt_index - 无参数的选项返回空" {
	args.parse -v
	result=$(args.opt_index "-v")
	[ -z "$result" ]
}

@test "args.opt_index - 不存在的选项返回空" {
	args.parse -f file.txt
	result=$(args.opt_index "-x")
	[ -z "$result" ]
}

# ============ args.args 测试 ============

@test "args.args - 返回最终参数数组名" {
	args.parse arg1 arg2 arg3
	result=$(args.args)
	[ "$result" = "_ARGS_FINAL_ARGS" ]
}

@test "args.args - 验证后返回最终参数数组" {
	args.init
	args.add_options "file" "f" "文件" "FILE"
	args.add_options "arg" "a" "安静模式"
	args.parse -f file.txt arg1 arg2
	args.verify
	result=$(args.args)
	[ "$result" = "_ARGS_FINAL_ARGS" ]
}
