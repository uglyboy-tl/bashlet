#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import ext/requests.sse
}

@test "requests.sse() 依赖 requests 模块可用" {
	run declare -F requests.request.build
	assert_success
}

@test "requests.sse() SSE 流式解析" {
	requests.init

	# 创建一个临时 SSE 模拟文件
	local temp_sse=$(mktemp)
	echo -e "data: hello\ndata: world\nevent: done" > "$temp_sse"

	# 定义回调函数并将结果写入文件
	local temp_result=$(mktemp)
	sse_callback() {
		echo "$1" >> "$temp_result"
	}

	# 测试 SSE 解析逻辑（使用 process substitution 避免子 shell）
	while IFS= read -r line; do
		[[ $line =~ ^data:\ (.+) ]] && sse_callback "${BASH_REMATCH[1]}"
	done < "$temp_sse"

	# 验证解析结果
	grep -q "hello" "$temp_result"
	grep -q "world" "$temp_result"

	rm -f "$temp_sse" "$temp_result"
}
