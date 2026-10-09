#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import ext/llm
	requests.init
}

# ========== 默认值与设置项（非网络） ==========

@test "llm 默认值 - base_url 与 model" {
	[ "$OPENAI_BASE_URL" = "https://api.deepseek.com/v1" ]
	[ "$_LLM_MODEL" = "deepseek-chat" ]
}

@test "llm.api_key - 设置 API key" {
	llm.api_key "sk-test"
	[ "$OPENAI_API_KEY" = "sk-test" ]
}

@test "llm.base_url - 设置 base_url" {
	llm.base_url "https://example.com/v1"
	[ "$OPENAI_BASE_URL" = "https://example.com/v1" ]
}

@test "llm.model - 设置 model" {
	llm.model "gpt-x"
	[ "$_LLM_MODEL" = "gpt-x" ]
}

@test "llm.init - 初始化 requests（curl 就绪）" {
	run llm.init
	[ "$status" -eq 0 ]
	[ -n "$_REQUESTS_CURL" ]
}

# ========== SSE 回调解析（非网络） ==========

@test "llm._sse_callback - 解析 delta.content" {
	run llm._sse_callback '{"choices":[{"delta":{"content":"hi"}}]}'
	[ "$status" -eq 0 ]
	[ "$output" = "hi" ]
}

@test "llm._sse_callback - [DONE] 静默且成功" {
	run llm._sse_callback "[DONE]"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "llm._sse_callback - 无 content 时无输出" {
	run llm._sse_callback '{"choices":[{"delta":{}}]}'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}
