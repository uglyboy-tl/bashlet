#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
}

@test "init.sh - 初始化正常" {
	# 在当前环境（Bash 4.3+）中source应该成功
	import "std/init.sh"
	[ "$?" -eq 0 ]
}