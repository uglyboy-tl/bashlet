#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
    _common_setup
    source "$PROJECT_ROOT/core/args.sh"
    # 清理全局变量确保测试环境干净
    unset _ARGS_OPTS _ARGS_ARGS _ARGS_OPT_ARGS 2>/dev/null || true
}

teardown() {
    # 清理解析状态
    unset _ARGS_OPTS _ARGS_ARGS _ARGS_OPT_ARGS 2>/dev/null || true
}

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

@test "args.count - 统计三个位置参数" {
    args.parse arg1 arg2 arg3
    result=$(args.count)
    [ "$result" = "3" ]
}

@test "args.count - 统计选项参数值作为位置参数" {
    args.parse -v -f file.txt
    result=$(args.count)
    # 选项参数值重复存储，所以返回 1
    [ "$result" = "1" ]
}

@test "args.count - 无参数时返回 0" {
    args.parse
    result=$(args.count)
    [ "$result" = "0" ]
}

@test "args.parse - 解析混合短选项和长选项" {
    args.parse -v --verbose -f

    # 检查选项数组
    [ "${_ARGS_OPTS[0]}" = "-v" ]
    [ "${_ARGS_OPTS[1]}" = "--verbose" ]
    [ "${_ARGS_OPTS[2]}" = "-f" ]

    # 检查没有位置参数
    [ ${#_ARGS_ARGS[@]} -eq 0 ]

    # 检查没有选项参数
    [ ${#_ARGS_OPT_ARGS[@]} -eq 0 ]
}

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
    # file.txt 被重复存储，可以作为位置参数访问
    [ "$result" = "file.txt" ]
}

@test "args.has - 检查存在的短选项返回成功" {
    args.parse -v -f file.txt
    run args.has "-v"
    [ "$status" -eq 0 ]
}

@test "args.has - 检查不存在的选项返回失败" {
    args.parse -v -f file.txt
    run args.has "-x"
    [ "$status" -eq 1 ]
}

@test "args.has - 检查存在的长选项返回成功" {
    args.parse --verbose --output result.txt
    run args.has "--verbose"
    [ "$status" -eq 0 ]
}

@test "args.has - 检查带参数值的选项仍能检测到" {
    args.parse -f filename.txt --output result.txt
    run args.has "-f"
    [ "$status" -eq 0 ]
    run args.has "--output"
    [ "$status" -eq 0 ]
}

@test "args.parse - 仅解析位置参数" {
    args.parse file1.txt file2.txt file3.txt

    # 检查没有选项
    [ ${#_ARGS_OPTS[@]} -eq 0 ]

    # 检查位置参数
    [ "${_ARGS_ARGS[0]}" = "file1.txt" ]
    [ "${_ARGS_ARGS[1]}" = "file2.txt" ]
    [ "${_ARGS_ARGS[2]}" = "file3.txt" ]
    [ ${#_ARGS_ARGS[@]} -eq 3 ]

    # 检查没有选项参数
    [ ${#_ARGS_OPT_ARGS[@]} -eq 0 ]
}

@test "args.parse - 解析选项和位置参数混合" {
    args.parse -v --output file1.txt arg2.txt

    # 检查选项
    [ "${_ARGS_OPTS[0]}" = "-v" ]
    [ "${_ARGS_OPTS[1]}" = "--output" ]
    [ ${#_ARGS_OPTS[@]} -eq 2 ]

    # 检查位置参数（file1.txt 既是 --output 的参数值，也被当作位置参数）
    [ "${_ARGS_ARGS[0]}" = "file1.txt" ]
    [ "${_ARGS_ARGS[1]}" = "arg2.txt" ]
    [ ${#_ARGS_ARGS[@]} -eq 2 ]

    # 检查选项参数（args.get 返回索引，通过 args.arg 获取值）
    [ "$(args.get "--output")" = "file1.txt" ]
    [ ${#_ARGS_OPT_ARGS[@]} -eq 1 ]
}

@test "args.parse - 解析带参数值的多个选项" {
    args.parse -f filename.txt --output result.txt -v

    # 检查选项
    [ "${_ARGS_OPTS[0]}" = "-f" ]
    [ "${_ARGS_OPTS[1]}" = "--output" ]
    [ "${_ARGS_OPTS[2]}" = "-v" ]
    [ ${#_ARGS_OPTS[@]} -eq 3 ]

    # 检查位置参数（选项参数值重复存储）
    [ "${_ARGS_ARGS[0]}" = "filename.txt" ]
    [ "${_ARGS_ARGS[1]}" = "result.txt" ]
    [ ${#_ARGS_ARGS[@]} -eq 2 ]

    # 检查选项参数（args.get 返回索引，通过 args.arg 获取值）
    [ "$(args.get "-f")" = "filename.txt" ]
    [ "$(args.get "--output")" = "result.txt" ]
    [ ${#_ARGS_OPT_ARGS[@]} -eq 2 ]
}

@test "args.parse - 正确处理 -- 分隔符" {
    args.parse -v --output file.txt -- arg1.txt -f arg2.txt

    # 检查选项
    [ "${_ARGS_OPTS[0]}" = "-v" ]
    [ "${_ARGS_OPTS[1]}" = "--output" ]
    [ ${#_ARGS_OPTS[@]} -eq 2 ]

    # 检查位置参数（包括 file.txt，因为重复存储）
    [ "${_ARGS_ARGS[0]}" = "file.txt" ]
    [ "${_ARGS_ARGS[1]}" = "arg1.txt" ]
    [ "${_ARGS_ARGS[2]}" = "-f" ]
    [ "${_ARGS_ARGS[3]}" = "arg2.txt" ]
    [ $(args.count) -eq 4 ]

    # 检查选项参数（args.get 返回索引，通过 args.arg 获取值）
    [ "$(args.get "--output")" = "file.txt" ]
    [ ${#_ARGS_OPT_ARGS[@]} -eq 1 ]
}

@test "边界条件 - 解析空参数列表" {
    args.parse

    # 检查没有选项
    [ ${#_ARGS_OPTS[@]} -eq 0 ]

    # 检查没有位置参数
    [ ${#_ARGS_ARGS[@]} -eq 0 ]
}

@test "边界条件 - 拒绝重复的选项" {
    run args.parse -v -v -v
    [ "$status" -ne 0 ]
}

@test "边界条件 - 正确处理特殊字符参数值" {
    args.parse -f "file with spaces.txt" --key "value\$VAR"

    # 检查选项参数值中的特殊字符（args.get 返回索引）
    [ "$(args.get "-f")" = "file with spaces.txt" ]
    [ "$(args.get "--key")" = 'value$VAR' ]
}

@test "边界条件 - 正确解析混合短选项和长选项" {
    args.parse -v --verbose -f file.txt --output result.txt

    # 检查混合选项
    [ "${_ARGS_OPTS[0]}" = "-v" ]
    [ "${_ARGS_OPTS[1]}" = "--verbose" ]
    [ "${_ARGS_OPTS[2]}" = "-f" ]
    [ "${_ARGS_OPTS[3]}" = "--output" ]
    [ ${#_ARGS_OPTS[@]} -eq 4 ]
}

@test "集成测试 - 典型命令行工具场景" {
    args.parse -v -f input.txt --output output.txt

    # 检查 verbose 模式
    run args.has "-v"
    [ "$status" -eq 0 ]

    # 检查文件参数（args.get 返回索引）
    [ "$(args.get "-f")" = "input.txt" ]
    [ "$(args.get "--output")" = "output.txt" ]

    # 检查位置参数（选项参数值重复存储）
    [ "${_ARGS_ARGS[0]}" = "input.txt" ]
    [ "${_ARGS_ARGS[1]}" = "output.txt" ]
    [ $(args.count) -eq 2 ]
}

@test "集成测试 - -- 分隔符分隔选项和参数" {
    args.parse -v file1.txt -- -f file2.txt

    # 检查分隔符前的选项和参数
    run args.has "-v"
    [ "$status" -eq 0 ]
    [ "${_ARGS_ARGS[0]}" = "file1.txt" ]

    # 检查分隔符后的参数不被解析为选项
    [ "${_ARGS_ARGS[1]}" = "-f" ]
    [ "${_ARGS_ARGS[2]}" = "file2.txt" ]
}

@test "集成测试 - 解析多个混合选项和参数" {
    args.parse -a -b --long1 val1 -c --long2 val2

    # 检查所有选项
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

    # 检查选项参数值（args.get 返回索引）
    [ "$(args.get "--long1")" = "val1" ]
    [ "$(args.get "--long2")" = "val2" ]

    # 检查位置参数（选项参数值重复存储）
    [ "${_ARGS_ARGS[0]}" = "val1" ]
    [ "${_ARGS_ARGS[1]}" = "val2" ]
    [ $(args.count) -eq 2 ]
}

@test "组合参数 - 将 -vab 分解为 -v -a -b" {
    args.parse -vab

    # 检查组合参数被正确分解
    [ "${_ARGS_OPTS[0]}" = "-v" ]
    [ "${_ARGS_OPTS[1]}" = "-a" ]
    [ "${_ARGS_OPTS[2]}" = "-b" ]
    [ ${#_ARGS_OPTS[@]} -eq 3 ]

    # 检查选项存在
    run args.has "-v"
    [ "$status" -eq 0 ]
    run args.has "-a"
    [ "$status" -eq 0 ]
    run args.has "-b"
    [ "$status" -eq 0 ]

    # 检查没有位置参数
    [ $(args.count) -eq 0 ]
}

@test "组合参数 - 混合组合参数和普通参数" {
    args.parse -xv --force file.txt

    # 检查组合参数分解
    [ "${_ARGS_OPTS[0]}" = "-x" ]
    [ "${_ARGS_OPTS[1]}" = "-v" ]
    [ "${_ARGS_OPTS[2]}" = "--force" ]
    [ ${#_ARGS_OPTS[@]} -eq 3 ]
}

@test "组合参数 - 处理多个连续的组合参数" {
    args.parse -vab -cde file.txt

    # 检查组合参数分解
    [ "${_ARGS_OPTS[0]}" = "-v" ]
    [ "${_ARGS_OPTS[1]}" = "-a" ]
    [ "${_ARGS_OPTS[2]}" = "-b" ]
    [ "${_ARGS_OPTS[3]}" = "-c" ]
    [ "${_ARGS_OPTS[4]}" = "-d" ]
    [ "${_ARGS_OPTS[5]}" = "-e" ]
    [ ${#_ARGS_OPTS[@]} -eq 6 ]

    # 检查位置参数
    [ "${_ARGS_ARGS[0]}" = "file.txt" ]
    [ $(args.count) -eq 1 ]
}

@test "组合参数 - 组合参数后不存储选项参数值" {
    args.parse -vf file.txt

    # 检查组合参数分解
    [ "${_ARGS_OPTS[0]}" = "-v" ]
    [ "${_ARGS_OPTS[1]}" = "-f" ]
    [ ${#_ARGS_OPTS[@]} -eq 2 ]

    # 检查选项存在
    run args.has "-v"
    [ "$status" -eq 0 ]
    run args.has "-f"
    [ "$status" -eq 0 ]

    # 检查位置参数
    [ "${_ARGS_ARGS[0]}" = "file.txt" ]
    [ $(args.count) -eq 1 ]

    # 检查 _ARGS_OPT_ARGS 为空（组合选项无参数值）
    [ ${#_ARGS_OPT_ARGS[@]} -eq 0 ]
    run args.get "-v"
    [ "$status" -ne 0 ]
    run args.get "-f"
    [ "$status" -ne 0 ]
}
