#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import ext/json
}

# ============ 定位（import 时完成） ============

@test "json.available() 有 jq 时返回 0" {
	run json.available
	[ "$status" -eq 0 ]
}

# ============ 跑程序 ============

@test "json.require() 缺 jq 时 exit 1（供包在自己的入口调一次）" {
	local tmp="$BATS_TEST_TMPDIR"
	printf '#!/usr/bin/env bash\nimport ext/json\necho "入口 OK"\njson.require\necho "不该到这"\n' > "$tmp/s.sh"
	"$PROJECT_ROOT/tools/build" -o "$tmp/gen" "$tmp/s.sh" > /dev/null 2>&1 || skip "构建失败"
	mkdir -p "$tmp/nopath"
	run env PATH="$tmp/nopath" "$BASH" "$tmp/gen"
	[ "$status" -eq 1 ]
	[[ "$output" == *"入口 OK"* ]]
	[[ "$output" != *"不该到这"* ]]
}

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

@test "json.run() 透传 jq 的退出码" {
	run json.run -n 'error("boom")'
	[ "$status" -ne 0 ]
}

@test "json: 缺 jq 时 import 不失败，json.run 才报错退出" {
	local tmp="$BATS_TEST_TMPDIR"
	printf '#!/usr/bin/env bash\nimport ext/json\necho "加载 OK"\njson.run -nr "1"\necho "不该到这"\n' > "$tmp/s.sh"
	"$PROJECT_ROOT/tools/build" -o "$tmp/gen" "$tmp/s.sh" > /dev/null 2>&1 || skip "构建失败"
	mkdir -p "$tmp/nopath"
	run env PATH="$tmp/nopath" "$BASH" "$tmp/gen"
	[ "$status" -eq 1 ]
	[[ "$output" == *"加载 OK"* ]]
	[[ "$output" == *"required command not found: jq"* ]]
	[[ "$output" != *"不该到这"* ]]
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
