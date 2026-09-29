#!/usr/bin/env bash

import ext/requests

# SSE 流式请求。仅少数脚本（如 llm）需要，独立成模块以免给普通 HTTP 客户端增重。
requests.sse() {
	local -r callback="$1"
	local -r method="$2"
	local -r url="$3"
	local -r body="$4"
	local -r content_type="${5:-$(requests.content_type.detect "$4")}"

	local curl_cmd
	requests.request.build curl_cmd "$method" "$url" "$body" "$content_type" || return 1
	curl_cmd+=("-N")

	"${curl_cmd[@]}" | while IFS= read -r line; do
		[[ $line =~ ^data:\ (.+) ]] && "$callback" "${BASH_REMATCH[1]}"
	done
}
