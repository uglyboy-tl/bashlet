#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import ext/json
}

# ============ 定位（import 时完成） ============

@test "json.bin() 返回可执行的 jq 路径" {
	run json.bin
	[ "$status" -eq 0 ]
	[ -x "$output" ]
}

# ============ 跑程序 ============

@test "json.run() 转发 jq 参数" {
	run json.run -nr '1'
	[ "$status" -eq 0 ]
	[ "$output" = "1" ]
}

@test "json.run() 支持 --arg" {
	run json.run -c -n --arg x hi '{x: $x}'
	[ "$status" -eq 0 ]
	[ "$output" = '{"x":"hi"}' ]
}

# ============ 取值 ============

@test "json.get() 缺省 filter 为 ." {
	run json.get '"hi"'
	[ "$status" -eq 0 ]
	[ "$output" = "hi" ]
}

@test "json.get() 按 filter 取值" {
	run json.get '{"a":{"b":"hi"}}' '.a.b'
	[ "$status" -eq 0 ]
	[ "$output" = "hi" ]
}

@test "json.get() 走完整 jq 程序（不止取值）" {
	run json.get '{"a":[1,2]}' '.a | length'
	[ "$status" -eq 0 ]
	[ "$output" = "2" ]
}

@test "json.get() 非法 JSON 返回非 0" {
	run json.get 'not json'
	[ "$status" -ne 0 ]
}
