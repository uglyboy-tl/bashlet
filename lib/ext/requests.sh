#!/usr/bin/env bash
# shellcheck disable=SC2016

import std/string
import std/system
import std/array
import std/fs
import core/log
import ext/json

declare -g _REQUESTS_TIMEOUT=30
declare -g _REQUESTS_USER_AGENT="bashlet-requests/1.0"
declare -g _REQUESTS_BASE_URL=""
declare -gA _REQUESTS_HEADERS=()
declare -gA _REQUESTS_AUTH=()
declare -g _REQUESTS_CURL=""

# curl 的探活留在 init：init 是请求路径的必经关口（重置默认头/认证/base_url），放这里不增加调用方负担，
# 缺 curl 也在准备阶段就报出来。jq 归 ext/json，import 它时即探活（无状态模块没有 init 可挂）。
# 用法约束：所有请求函数前必须先调 requests.init（它负责定位 curl 并重置默认头/认证/base_url）。
requests.init() {
	declare -ga _REQUESTS_CURL_EXTRA=("$@")

	system.command.required "curl" && _REQUESTS_CURL="$(command -v curl)"

	_REQUESTS_HEADERS=(
		["Accept"]="*/*"
		["Accept-Encoding"]="gzip, deflate"
		["Connection"]="keep-alive"
	)
	# 一并清掉上一轮的认证与 base_url，否则同进程内复用（如逐 provider 循环）会串凭证/串域名
	_REQUESTS_AUTH=()
	_REQUESTS_BASE_URL=""

	log.debug "requests module initialized: curl=$_REQUESTS_CURL, jq=$(json.bin)"
	return 0
}

requests.curl.configure() {
	local array_name="$1"
	local timeout="${2:-}"
	local include_auth="${3:-true}"

	[[ -n $timeout ]] && array.append "$array_name" "--max-time" "$timeout"
	array.append "$array_name" "-A" "$_REQUESTS_USER_AGENT"

	local key
	for key in "${!_REQUESTS_HEADERS[@]}"; do
		array.append "$array_name" "-H" "${key}: ${_REQUESTS_HEADERS[$key]}"
	done

	if [[ $include_auth == "true" && ${#_REQUESTS_AUTH[@]} -gt 0 ]]; then
		local auth_key
		for auth_key in "${!_REQUESTS_AUTH[@]}"; do
			array.append "$array_name" "-H" "${auth_key}: ${_REQUESTS_AUTH[$auth_key]}"
		done
	fi
}

requests.request.build() {
	local -n cmd_ref="$1"
	local -r method="$2"
	local -r url="$3"
	local -r body="$4"
	local -r content_type="${5:-$(requests.content_type.detect "$4")}"

	# -L：跟随 3xx（GitHub raw 等必有跳转，不跟随会拿到空 body + 3xx 状态码）
	# -X：只在 curl 自己推不出方法时补（GET/HEAD 与带 body 的 POST 都能推出来）。
	# 带 body 的 POST 不传 -X，才能让 curl 对 301/302/303 按规范降级为 GET，
	# 而不是像 -X POST 那样保留方法却把 body 丢掉（发个没有 body 的 POST）。
	cmd_ref=("$_REQUESTS_CURL" "-s" "-L" "--compressed")
	if [[ $method != POST || -z $body ]]; then
		cmd_ref+=("-X" "$method")
	fi
	cmd_ref+=("${_REQUESTS_CURL_EXTRA[@]}")

	requests.curl.configure cmd_ref "$_REQUESTS_TIMEOUT"

	if [[ -n $body ]]; then
		cmd_ref+=("-d" "$body")
		[[ -n $content_type ]] && cmd_ref+=("-H" "Content-Type: $content_type")
	fi

	local full_url="$url"
	[[ -n $_REQUESTS_BASE_URL ]] && full_url="${_REQUESTS_BASE_URL}${url}"
	cmd_ref+=("$full_url")
}

# 解析 curl -D 转储的响应头文件为 JSON。
# -L 跟随跳转时文件里有多个响应块（中间的 3xx + 最终响应），只取最后一个：
# 中间响应独有的 ETag/Last-Modified 若被 requests.cache 当成最终资源的验证器存下来，
# 下次条件请求就会拿错值（最坏是巧合命中，拿到错误的 304）。
requests._headers_json() {
	json.run -Rs '[splits("\r?\n\r?\n")] | map(select(length > 0)) | last // "" | split("\n") | map(select(length > 0 and test(":"))) | map(split(": ") | {(.[0]): .[1] | rtrimstr("\r")}) | add // {}' "$1"
}

requests.request() {
	local -r method="$1"
	local -r url="$2"
	local -r body="$3"
	local -r content_type="$4"

	local curl_cmd
	requests.request.build curl_cmd "$method" "$url" "$body" "$content_type" || return 1

	# 创建临时文件（第二个失败时要收拾第一个，已不用 trap）
	local temp_body
	temp_body="$(fs.mktemp)" || return 1
	local temp_headers
	temp_headers="$(fs.mktemp)" || {
		rm -f "$temp_body"
		return 1
	}

	# 执行 curl 命令；用 || 抑制 errexit 以保住 curl 退出码：
	# 传输中断/截断时即使 HTTP 是 2xx 也不算成功
	local status_code curl_exit=0
	status_code=$("${curl_cmd[@]}" -w "%{http_code}" -D "$temp_headers" -o "$temp_body" 2> /dev/null) || curl_exit=$?

	# 不用 local x="$(...)"：local 恒返回 0，会把下面几处的失败吞掉
	local body_base64 headers_json
	body_base64="$(string.base64.encode "$temp_body")" || {
		rm -f "$temp_body" "$temp_headers"
		return 1
	}
	headers_json="$(requests._headers_json "$temp_headers")" || {
		rm -f "$temp_body" "$temp_headers"
		return 1
	}

	# 判断是否成功 (curl 正常结束且 2xx)
	local success="false"
	[[ $status_code =~ ^2[0-9][0-9]$ && $curl_exit -eq 0 ]] && success="true"

	# 构建 JSON 响应
	rm -f "$temp_body" "$temp_headers"
	echo "{\"status_code\":$status_code,\"curl_exit\":$curl_exit,\"headers\":$headers_json,\"body\":\"$body_base64\",\"success\":$success}"
}

requests.download() {
	local curl_cmd=("$_REQUESTS_CURL" "-L" "--globoff" "--fail")
	# 默认不附加认证头，与 requests.get()/post() 行为不同，
	# 如需认证请使用 URL 参数或直接调用 requests.request()
	requests.curl.configure curl_cmd "" false
	curl_cmd+=("-o" "$2")

	# 是否显示进度
	[[ ${3:-true} == "true" ]] && curl_cmd+=("--progress-bar")

	# 是否启用断点续传
	[[ ${4:-true} == "true" ]] && curl_cmd+=("-C" "-")

	# 执行下载
	"${curl_cmd[@]}" "$1"
}

# URL 编码辅助函数
requests._urlencode() {
	json.run -nr --arg str "$1" '$str | @uri'
}

# 自动检测 Content-Type 辅助函数
requests.content_type.detect() {
	# 检查是否以 { 开头以 } 结尾（简单 JSON 检测）
	[[ $1 =~ ^\{.*\}$ ]] && echo "application/json" && return 0
	[[ $1 =~ ^\[.*\]$ ]] && echo "application/json" && return 0
	[[ $1 =~ ^[a-zA-Z0-9_-]+=[^\&]+(\&[a-zA-Z0-9_-]+=[^\&]+)*$ ]] && echo "application/x-www-form-urlencoded" && return 0
	echo ""
}

requests.body.build() {
	local -n ref="$1"
	local first=true
	if [[ ${2:-form} == "json" ]]; then
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
requests.query.build() {
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
requests.get() { requests.request "GET" "$1$(requests.query.build "${@:2}")" "" ""; }

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
requests.status_code() { json.run -r '.status_code' <<< "$1"; }

# 提取 curl 退出码（非 0 表示传输层失败，即使 HTTP 是 2xx）
requests.exit_code() { json.run -r '.curl_exit' <<< "$1"; }

# 提取响应头 (可选指定字段名)
requests.headers() { [[ -n ${2:-} ]] && json.run -r --arg name "$2" '.headers[$name] // empty' <<< "$1" || json.run -r '.headers' <<< "$1"; }

requests.text() { json.run -r '.body' <<< "$1" | string.base64.decode; }

# 提取 JSON 响应 (可选 JSONPath)
requests.json() {
	local -r body_text="$(requests.text "$1")"
	[[ -n ${2:-} ]] && json.get "$body_text" "$2" || echo "$body_text"
}

# 检查是否成功 (2xx)
requests.success() { json.run -r '.success' <<< "$1"; }

# 检查 HTTP 错误，非零退出 (类似 requests.raise_for_status())
requests.raise_for_status() { [[ "$(requests.success "${1:-}")" == "true" ]] || { log.error "HTTP error: status $(requests.status_code "${1:-}") curl_exit $(requests.exit_code "${1:-}")" && return 1; }; }

# 设置超时时间 (秒)
requests.timeout() { string.natural.check "$1" && _REQUESTS_TIMEOUT="$1" || { log.error "timeout must be a positive integer" && return 1; }; }

# 设置默认请求头 (可变参数: key1 value1 key2 value2 ...)
requests.headers.append() {
	# 接受键值对参数
	local key="${1:-}"
	shift

	while [[ -n $key ]]; do
		local value="$1"
		shift
		_REQUESTS_HEADERS["$key"]="$value"
		log.debug "default header set: $key" # 不记值，避免密钥进日志

		# 获取下一个键值对
		key="${1:-}"
		shift || true
	done
}

# 设置基础 URL (用于相对路径请求)
requests.base_url() { _REQUESTS_BASE_URL="$1"; }

# 清空默认请求头
requests.headers.clear() { _REQUESTS_HEADERS=(); }

# 设置 Basic Auth (用户名 密码)
requests.auth() { _REQUESTS_AUTH["Authorization"]="Basic $(json.run -nr --arg c "$1:$2" '$c | @base64')"; }

# 设置 Bearer Token
requests.auth_bearer() { _REQUESTS_AUTH["Authorization"]="Bearer $1"; }
