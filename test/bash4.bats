#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
    _common_setup
}

teardown() {
    # 清理环境变量
    unset __loaded_modules 2>/dev/null || true
}

@test "bash4.sh - Bash 4+ 环境正常加载" {
    # 在当前环境（Bash 4+）中source应该成功
    import "std/bash4.sh"
    [ "$?" -eq 0 ]
}