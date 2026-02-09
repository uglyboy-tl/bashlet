#!/usr/bin/env bash

import std/system
import std/fs
import core/log

declare -g _REQUESTS_TIMEOUT=30
declare -g _REQUESTS_USER_AGENT="bashlet-requests/1.0"
declare -g _REQUESTS_BASE_URL=""
declare -gA _REQUESTS_HEADERS=()
declare -gA _REQUESTS_AUTH=()
declare -g _REQUESTS_CURL=""
declare -g _REQUESTS_JQ=""

requests.init() {
	system.command.required "curl" && _REQUESTS_CURL="$(command -v curl)"
	system.command.required "jq" && _REQUESTS_JQ="$(command -v jq)"

	_REQUESTS_HEADERS=(
		["Accept"]="*/*"
		["Accept-Encoding"]="gzip, deflate"
		["Connection"]="keep-alive"
	)

	log.debug "requests module initialized: curl=$_REQUESTS_CURL, jq=$_REQUESTS_JQ"
	return 0
}

requests.curl.check() {
	[[ -n "$_REQUESTS_CURL" ]] || _REQUESTS_CURL="$(command -v curl)"
}

requests.jq.check() {
	[[ -n "$_REQUESTS_JQ" ]] || _REQUESTS_JQ="$(command -v jq)"
}

requests.curl.configure() {
	local array_name="$1"

	requests._append_to_array "$array_name" "--max-time" "$_REQUESTS_TIMEOUT"
	requests._append_to_array "$array_name" "-A" "$_REQUESTS_USER_AGENT"

	local key
	for key in "${!_REQUESTS_HEADERS[@]}"; do
		requests._append_to_array "$array_name" "-H" "${key}: ${_REQUESTS_HEADERS[$key]}"
	done

	if [[ ${#_REQUESTS_AUTH[@]} -gt 0 ]]; then
		local auth_key
		for auth_key in "${!_REQUESTS_AUTH[@]}"; do
			requests._append_to_array "$array_name" "-H" "${auth_key}: ${_REQUESTS_AUTH[$auth_key]}"
		done
	fi
}

requests._append_to_array() {
	local -n array_ref="$1"
	shift
	array_ref+=("$@")
}

requests._build_curl_request() {
	local -n cmd_ref="$1"
	local -r method="$2"
	local -r url="$3"
	local -r body="$4"
	local -r content_type="${5:-$(requests.content_type.detect "$4")}"

	cmd_ref=("$_REQUESTS_CURL" "-s" "--compressed" "-X" "$method")

	requests.curl.configure cmd_ref

	if [[ -n "$body" ]]; then
		cmd_ref+=("-d" "$body")
		[[ -n "$content_type" ]] && cmd_ref+=("-H" "Content-Type: $content_type")
	fi

	local full_url="$url"
	[[ -n "$_REQUESTS_BASE_URL" ]] && full_url="${_REQUESTS_BASE_URL}${url}"
	cmd_ref+=("$full_url")
}

requests.request() {
	local -r method="$1"
	local -r url="$2"
	local -r body="$3"
	local -r content_type="$4"

	requests.curl.check || return 1
	requests.jq.check || return 1

	local curl_cmd
	requests._build_curl_request curl_cmd "$method" "$url" "$body" "$content_type" || return 1

	# 创建临时文件
	local temp_body="$(fs.mktemp)" || return 1
	local temp_headers="$(fs.mktemp)" || return 1

	trap 'rm -f "${temp_body:-}" "${temp_headers:-}"' EXIT

	# 执行 curl 命令
	local status_code=$("${curl_cmd[@]}" -w "%{http_code}" -D "$temp_headers" -o "$temp_body" 2>/dev/null)

	local body_base64="$(requests.base64.encode "$temp_body")"

	# 解析响应头为 JSON (使用 jq)
	local headers_json="$("$_REQUESTS_JQ" -Rs 'split("\n") | map(select(length > 0 and test(":"))) | map(split(": ") | {(.[0]): .[1] | rtrimstr("\r")}) | add // {}' "$temp_headers")"

	# 判断是否成功 (2xx 状态码)
	local success="false"
	[[ $status_code =~ ^2[0-9][0-9]$ ]] && success="true"

	# 构建 JSON 响应
	echo "{\"status_code\":$status_code,\"headers\":$headers_json,\"body\":\"$body_base64\",\"success\":$success}"
}

requests.download() {
	requests.curl.check || return 1
	local curl_cmd=("$_REQUESTS_CURL" "-L")
	requests.curl.configure curl_cmd
	curl_cmd+=("-o" "$2")

	# 是否显示进度
	[[ "${3:-true}" == "true" ]] && curl_cmd+=("--progress-bar" "-s")

	# 是否启用断点续传
	[[ "${4:-true}" == "true" ]] && curl_cmd+=("-C" "-")

	# 执行下载
	"${curl_cmd[@]}" "$1"
}

requests.sse() {
	local -r callback="$1"
	local -r method="$2"
	local -r url="$3"
	local -r body="$4"
	local -r content_type="$5"

	requests.curl.check || return 1

	local curl_cmd
	requests._build_curl_request curl_cmd "$method" "$url" "$body" "$content_type" || return 1
	curl_cmd+=("--no-buffer")

	"${curl_cmd[@]}" | while IFS= read -r line; do
		[[ "$line" =~ ^data:\ (.+) ]] && "$callback" "${BASH_REMATCH[1]}"
	done
}

# URL 编码辅助函数
requests._urlencode() {
	echo "$("$_REQUESTS_JQ" -nr --arg str "$1" '$str | @uri')"
}

# 自动检测 Content-Type 辅助函数
requests.content_type.detect() {
	# 检查是否以 { 开头以 } 结尾（简单 JSON 检测）
	[[ "$1" =~ ^\{.*\}$ ]] && echo "application/json" && return 0
	[[ "$1" =~ ^\[.*\]$ ]] && echo "application/json" && return 0
	[[ "$1" =~ ^[a-zA-Z0-9_-]+=[^\&]+(\&[a-zA-Z0-9_-]+=[^\&]+)*$ ]] && echo "application/x-www-form-urlencoded" && return 0
	echo ""
}

requests.body_from_map() {
	local -n ref="$1"
	local first=true
	requests.jq.check || return 1
	if [[ "${2:-form}" == "json" ]]; then
		printf "{"
		for key in "${!ref[@]}"; do
			$first || printf ","
			printf '"%s":"%s"' "$key" "${ref[$key]}"
			first=false
		done
		printf "}\n"
	else
		for key in "${!ref[@]}"; do
			$first || printf "&"
			printf '%s=%s' "$(requests._urlencode "$key")" "$(requests._urlencode "${ref[$key]}")"
			first=false
		done
		printf "\n"
	fi
}

# 构建查询字符串 - 将参数数组转换为 URL 编码的查询字符串
requests.build.query() {
	local query="" first=true
	for param in "$@"; do
		# 分割 key=value
		local key="${param%%=*}" value="${param#*=}"
		# 构建查询字符串
		if $first; then
			query="?$(requests._urlencode "$key")=$(requests._urlencode "$value")"
			first=false
		else
			query="${query}&$(requests._urlencode "$key")=$(requests._urlencode "$value")"
		fi
	done
	echo "$query"
}

# GET 请求 - 接受 URL 和可选的查询参数
requests.get() { requests.request "GET" "$1$(requests.build.query "${@:2}")" "" ""; }

# POST 请求 - 接受 URL、请求体和可选的 Content-Type
requests.post() { requests.request "POST" "$1" "$2" "${3:-}"; }

# PUT 请求
requests.put() { requests.request "PUT" "$1" "$2" "${3:-}"; }

# DELETE 请求
requests.delete() { requests.request "DELETE" "$1" "" ""; }

# PATCH 请求
requests.patch() { requests.request "PATCH" "$1" "$2" "${3:-}"; }

# HEAD 请求 - 只返回响应头
requests.head() { requests.request "HEAD" "$1" "" ""; }

# OPTIONS 请求 - 返回允许的方法
requests.options() { requests.request "OPTIONS" "$1" "" ""; }

# 提取状态码
requests.status_code() { "$_REQUESTS_JQ" -r '.status_code' <<<"$1"; }

# 提取响应头 (可选指定字段名)
requests.headers() {
	requests.jq.check || return 1

	[[ -n "${2:-}" ]] && "$_REQUESTS_JQ" -r --arg name "$2" '.headers[$name] // empty' <<<"$1" || "$_REQUESTS_JQ" -r '.headers' <<<"$1"
}

requests.base64.encode() {
	base64 -w 0 "$1" 2>/dev/null || base64 "$1" 2>/dev/null
}

requests.base64.decode() {
	base64 -d 2>/dev/null || base64 -D 2>/dev/null
}

requests.text() {
	requests.jq.check || return 1

	"$_REQUESTS_JQ" -r '.body' <<<"$1" | requests.base64.decode
}

# 提取 JSON 响应 (可选 JSONPath)
requests.json() {
	local -r body_text="$(requests.text "$1")"

	[[ -n "${2:-}" ]] && "$_REQUESTS_JQ" -r "$2" <<<"$body_text" || echo "$body_text"
}

# 检查是否成功 (2xx)
requests.success() { "$_REQUESTS_JQ" -r '.success' <<<"$1"; }

# 检查 HTTP 错误，非零退出 (类似 requests.raise_for_status())
requests.raise_for_status() {
	requests.jq.check || return 1

	# 如果不成功，返回非零状态码
	[[ "$(requests.success "${1:-}")" == "true" ]] || { log.error "HTTP error: status code $(requests.status_code "${1:-}")" && return 1; }
}

# 设置超时时间 (秒)
requests.timeout() {
	local -r seconds="$1"

	# 验证输入参数：必须为正整数
	[[ "$seconds" =~ ^[0-9]+$ ]] && ((seconds > 0)) || { log.error "timeout must be a positive integer" && return 1; }

	_REQUESTS_TIMEOUT="$seconds"
	log.debug "timeout set to ${seconds}s"
}

# 设置基础 URL (用于相对路径请求)
requests.base_url() {
	_REQUESTS_BASE_URL="$1"
	log.debug "base URL set to: $1"
}

# 设置默认请求头 (可变参数: key1 value1 key2 value2 ...)
requests.default_headers() {
	# 接受键值对参数
	local key="${1:-}"
	shift

	while [[ -n "$key" ]]; do
		local value="$1"
		shift
		_REQUESTS_HEADERS["$key"]="$value"
		log.debug "default header set: $key: $value"

		# 获取下一个键值对
		key="${1:-}"
		shift || true
	done
}

# 清空默认请求头
requests.headers_clear() {
	_REQUESTS_HEADERS=()
	log.debug "default headers cleared"
}

# 设置 Basic Auth (用户名 密码)
requests.auth() {
	_REQUESTS_AUTH["Authorization"]="Basic $(jq -nr --arg c "$1:$2" '$c | @base64')"
	log.debug "Basic Auth set for user: $1"
}

# 设置 Bearer Token
requests.auth_bearer() {
	_REQUESTS_AUTH["Authorization"]="Bearer $1"
	log.debug "Bearer Token set"
}
