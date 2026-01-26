#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
    _common_setup
    source "$PROJECT_ROOT/std/console.sh"
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
