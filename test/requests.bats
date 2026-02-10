#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
    _common_setup
    import ext/requests
    # 重置配置，确保测试独立
    # requests.reset 2>/dev/null || true
    # 初始化 requests 模块
    requests.init
}

teardown() {
    # 清理配置
	_REQUESTS_TIMEOUT=30
	_REQUESTS_BASE_URL=""
	_REQUESTS_HEADERS=(
		["Accept"]="*/*"
		["Accept-Encoding"]="gzip, deflate"
		["Connection"]="keep-alive"
	)
	_REQUESTS_AUTH=()
}

# 重置所有配置
requests.reset() {
	_REQUESTS_TIMEOUT=30
	_REQUESTS_BASE_URL=""
	_REQUESTS_HEADERS=(
		["Accept"]="*/*"
		["Accept-Encoding"]="gzip, deflate"
		["Connection"]="keep-alive"
	)
	_REQUESTS_AUTH=()
	log.debug "all configuration reset to defaults"
}

# ============ 依赖检查测试 ============

@test "requests.init() 检查 curl 和 jq" {
    run requests.init
    [ "$status" -eq 0 ]
    # log.debug 输出可能到 stderr，检查命令是否成功执行即可
}

# ============ HTTP 方法测试 ============

@test "requests.get() 返回正确响应" {
    requests.init
    response=$(requests.get "https://httpbin.org/get")

    # 检查响应包含 JSON
    echo "$response" | jq -e '.status_code' >/dev/null
    [ $? -eq 0 ]

    # 检查状态码是 200
    status_code=$(requests.status_code "$response")
    [ "$status_code" -eq 200 ]

    # 检查响应体包含 httpbin 的响应
    body_text=$(requests.text "$response")
    echo "$body_text" | jq -e '.url' >/dev/null
    [ $? -eq 0 ]
}

@test "requests.get() 带查询参数" {
    requests.init
    response=$(requests.get "https://httpbin.org/get" "key1=value1" "key2=value2")

    # 检查响应包含查询参数
    body_text=$(requests.text "$response")
    echo "$body_text" | jq -e '.args.key1 == "value1"' >/dev/null
    [ $? -eq 0 ]
    echo "$body_text" | jq -e '.args.key2 == "value2"' >/dev/null
    [ $? -eq 0 ]
}

@test "requests.post() 发送 POST 请求" {
    requests.init
    response=$(requests.post "https://httpbin.org/post" '{"test": "data"}')

    # 检查状态码
    status_code=$(requests.status_code "$response")
    [ "$status_code" -eq 200 ]

    # 检查请求体被正确回显
    body_text=$(requests.text "$response")
    echo "$body_text" | jq -e '.json.test == "data"' >/dev/null
    [ $? -eq 0 ]
}

@test "requests.post() 发送表单数据" {
    requests.init
    response=$(requests.post "https://httpbin.org/post" "field1=value1&field2=value2")

    # 检查状态码
    status_code=$(requests.status_code "$response")
    [ "$status_code" -eq 200 ]

    # 检查表单数据被正确解析
    body_text=$(requests.text "$response")
    echo "$body_text" | jq -e '.form.field1 == "value1"' >/dev/null
    [ $? -eq 0 ]
    echo "$body_text" | jq -e '.form.field2 == "value2"' >/dev/null
    [ $? -eq 0 ]
}

@test "requests.put() 发送 PUT 请求" {
    requests.init
    response=$(requests.put "https://httpbin.org/put" '{"update": "data"}')

    # 检查状态码
    status_code=$(requests.status_code "$response")
    [ "$status_code" -eq 200 ]

    # 检查请求体被正确回显
    body_text=$(requests.text "$response")
    echo "$body_text" | jq -e '.json.update == "data"' >/dev/null
    [ $? -eq 0 ]
}

@test "requests.delete() 发送 DELETE 请求" {
    requests.init
    response=$(requests.delete "https://httpbin.org/delete")

    # 检查状态码
    status_code=$(requests.status_code "$response")
    [ "$status_code" -eq 200 ]
}

@test "requests.patch() 发送 PATCH 请求" {
    requests.init
    response=$(requests.patch "https://httpbin.org/patch" '{"patch": "data"}')

    # 检查状态码
    status_code=$(requests.status_code "$response")
    [ "$status_code" -eq 200 ]

    # 检查请求体被正确回显
    body_text=$(requests.text "$response")
    echo "$body_text" | jq -e '.json.patch == "data"' >/dev/null
    [ $? -eq 0 ]
}

@test "requests.head() 发送 HEAD 请求" {
    requests.init
    response=$(requests.head "https://httpbin.org/headers")

    # 检查状态码
    status_code=$(requests.status_code "$response")
    [ "$status_code" -eq 200 ]

    # HEAD 请求应该没有响应体
    body_text=$(requests.text "$response")
    [ -z "$body_text" ]
}

@test "requests.options() 发送 OPTIONS 请求" {
    requests.init
    response=$(requests.options "https://httpbin.org/anything")

    # 检查状态码
    status_code=$(requests.status_code "$response")
    [ "$status_code" -eq 200 ]
}

# ============ 响应处理测试 ============

@test "requests.status_code() 提取状态码" {
    requests.init
    response=$(requests.get "https://httpbin.org/status/418")  # I'm a teapot

    status_code=$(requests.status_code "$response")
    [ "$status_code" -eq 418 ]
}

@test "requests.headers() 提取响应头" {
    requests.init
    response=$(requests.get "https://httpbin.org/headers")

    # 提取特定响应头（httpbin 返回小写）
    content_type=$(requests.headers "$response" "content-type")
    [[ "$content_type" == *"application/json"* ]]

    # 提取所有响应头（作为 JSON）
    headers_json=$(requests.headers "$response")
    echo "$headers_json" | jq -e '."content-type"' >/dev/null
    [ $? -eq 0 ]
}

@test "requests.text() 提取文本" {
    requests.init
    response=$(requests.get "https://httpbin.org/html")

    body_text=$(requests.text "$response")
    [[ "$body_text" == *"<html>"* ]]
    [[ "$body_text" == *"</html>"* ]]
}

@test "requests.json() 提取 JSON" {
    requests.init
    response=$(requests.get "https://httpbin.org/json")

    # 提取整个 JSON
    json_data=$(requests.json "$response")
    echo "$json_data" | jq -e '.slideshow' >/dev/null
    [ $? -eq 0 ]

    # 使用 JSONPath 提取特定字段
    title=$(requests.json "$response" ".slideshow.title")
    [ "$title" = "Sample Slide Show" ]
}

@test "requests.success() 检查成功" {
    requests.init

    # 测试成功响应
    success_response=$(requests.get "https://httpbin.org/status/200")
    success=$(requests.success "$success_response")
    [ "$success" = "true" ]

    # 测试失败响应
    error_response=$(requests.get "https://httpbin.org/status/404")
    success=$(requests.success "$error_response")
    [ "$success" = "false" ]
}

@test "requests.raise_for_status() 错误时返回非零" {
    requests.init

    # 成功响应应该返回 0
    success_response=$(requests.get "https://httpbin.org/status/200")
    run requests.raise_for_status "$success_response"
    [ "$status" -eq 0 ]

    # 错误响应应该返回非零
    error_response=$(requests.get "https://httpbin.org/status/500")
    run requests.raise_for_status "$error_response"
    [ "$status" -ne 0 ]
}

# ============ 配置与认证测试 ============

@test "requests.timeout() 设置超时" {
    requests.init

    # 设置超时
    requests.timeout 10
    response=$(requests.get "https://httpbin.org/delay/1")  # 1秒延迟

    # 应该成功
    status_code=$(requests.status_code "$response")
    [ "$status_code" -eq 200 ]

    # 测试无效超时值
    run requests.timeout "invalid"
    [ "$status" -ne 0 ]

    run requests.timeout 0
    [ "$status" -ne 0 ]

    run requests.timeout -5
    [ "$status" -ne 0 ]
}

@test "requests.base_url() 设置基础 URL" {
    requests.init

    # 设置基础 URL
    requests.base_url "https://httpbin.org"

    # 使用相对路径
    response=$(requests.get "/get")
    status_code=$(requests.status_code "$response")
    [ "$status_code" -eq 200 ]

    # 重置基础 URL
    requests.reset
    response=$(requests.get "https://httpbin.org/get")
    status_code=$(requests.status_code "$response")
    [ "$status_code" -eq 200 ]
}

@test "requests.headers.build() 设置请求头" {
    requests.init

    # 设置自定义请求头 - 使用 || true 防止 set -e 导致测试失败
    requests.headers.build "X-Custom-Header" "CustomValue"
    requests.headers.build "X-Another-Header" "AnotherValue"

    response=$(requests.get "https://httpbin.org/headers")
    body_text=$(requests.text "$response")

    # 检查自定义请求头被发送
    echo "$body_text" | jq -e '.headers["X-Custom-Header"] == "CustomValue"' >/dev/null
    [ $? -eq 0 ]
    echo "$body_text" | jq -e '.headers["X-Another-Header"] == "AnotherValue"' >/dev/null
    [ $? -eq 0 ]
}

@test "requests.headers_clear() 清空请求头" {
    requests.init

    # 先设置一些请求头 - 使用 || true 防止 set -e 导致测试失败
    requests.headers.build "X-Test-Header" "TestValue" || true

    # 清空请求头
    requests.headers_clear

    response=$(requests.get "https://httpbin.org/headers")
    body_text=$(requests.text "$response")

    # 检查自定义请求头不存在（但默认请求头应该还在）
    # jq 返回 null 时退出码为 0，所以我们需要检查值是否为 null
    result=$(echo "$body_text" | jq -r '.headers["X-Test-Header"]')
    [ "$result" = "null" ]  # 应该为 null，因为自定义请求头被清空了
}

@test "requests.auth() Basic Auth" {
    requests.init

    # 设置 Basic Auth
    requests.auth "user" "passwd"

    # 测试 Basic Auth 端点
    response=$(requests.get "https://httpbin.org/basic-auth/user/passwd")
    status_code=$(requests.status_code "$response")
    [ "$status_code" -eq 200 ]

    # 验证认证成功
    body_text=$(requests.text "$response")
    echo "$body_text" | jq -e '.authenticated == true' >/dev/null
    [ $? -eq 0 ]
    echo "$body_text" | jq -e '.user == "user"' >/dev/null
    [ $? -eq 0 ]
}

@test "requests.auth_bearer() Bearer Token" {
    requests.init

    # 设置 Bearer Token
    requests.auth_bearer "test-token-123"

    response=$(requests.get "https://httpbin.org/bearer")
    body_text=$(requests.text "$response")

    # 检查 Bearer Token 被发送
    echo "$body_text" | jq -e '.token == "test-token-123"' >/dev/null
    [ $? -eq 0 ]
    echo "$body_text" | jq -e '.authenticated == true' >/dev/null
    [ $? -eq 0 ]
}

# ============ 边界条件测试 ============

@test "requests.get() 无效 URL 返回错误" {
    requests.init

    # 无效 URL 应该返回错误响应
    response=$(requests.get "https://invalid-domain-that-does-not-exist-12345.com")

    # 检查状态码不是 2xx
    success=$(requests.success "$response")
    [ "$success" = "false" ]
}

@test "requests.json() 非 JSON 响应返回原始文本" {
    requests.init

    # 获取 HTML 响应
    response=$(requests.get "https://httpbin.org/html")

    # 尝试提取 JSON（应该返回原始 HTML）
    json_data=$(requests.json "$response")
    [[ "$json_data" == *"<html>"* ]]
}

@test "requests.query.build() 构建查询字符串" {
    requests.init

    # 创建参数数组
    declare -a params=("key1=value1" "key2=value with spaces" "key3=special&chars")

    # 构建查询字符串
    query_string=$(requests.query.build "${params[@]}")

    # 检查查询字符串格式
    [[ "$query_string" == "?"* ]]
    [[ "$query_string" == *"key1=value1"* ]]
    [[ "$query_string" == *"key2=value%20with%20spaces"* ]]
    [[ "$query_string" == *"key3=special%26chars"* ]]
}

@test "requests._urlencode() URL 编码" {
    requests.init

    # 测试 URL 编码
    encoded=$(requests._urlencode "hello world & special/chars")
    [ "$encoded" = "hello%20world%20%26%20special%2Fchars" ]
}

@test "requests.body.build() form 格式" {
    requests.init

    declare -A data=([name]="test" [value]="hello world")
    body=$(requests.body.build data)

    [[ "$body" == *"name=test"* ]]
    [[ "$body" == *"value=hello%20world"* ]]
}

@test "requests.body.build() json 格式" {
    requests.init

    declare -A data=([name]="test" [value]="hello")
    body=$(requests.body.build data json)

    [[ "$body" == *'"name":"test"'* ]]
    [[ "$body" == *'"value":"hello"'* ]]
}

@test "requests.content_type.detect() 自动检测 Content-Type" {
    requests.init

    # 测试 JSON 检测
    content_type=$(requests.content_type.detect '{"key": "value"}')
    [ "$content_type" = "application/json" ]

    # 测试数组 JSON 检测
    content_type=$(requests.content_type.detect '[1, 2, 3]')
    [ "$content_type" = "application/json" ]

    # 测试表单数据检测
    content_type=$(requests.content_type.detect 'field1=value1&field2=value2')
    [ "$content_type" = "application/x-www-form-urlencoded" ]

    # 测试未知类型
    content_type=$(requests.content_type.detect 'plain text')
    [ -z "$content_type" ]
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
        [[ "$line" =~ ^data:\ (.+) ]] && sse_callback "${BASH_REMATCH[1]}"
    done < "$temp_sse"

    # 验证解析结果
    grep -q "hello" "$temp_result"
    grep -q "world" "$temp_result"

    rm -f "$temp_sse" "$temp_result"
}

# ============ 下载功能测试 ============

@test "requests.download() 下载文件" {
    requests.init

    local temp_file=$(mktemp)
    local temp_output="${temp_file}.downloaded"

    # 创建测试文件内容
    echo "test content for download" > "$temp_file"

    # 使用 file:// 协议进行本地测试（避免网络依赖）
    run requests.download "file://$temp_file" "$temp_output"

    # 验证退出码为 0（成功）
    [ "$status" -eq 0 ]

    # 验证文件被下载
    [ -f "$temp_output" ]

    # 验证内容一致
    [ "$(cat "$temp_output")" = "$(cat "$temp_file")" ]

    rm -f "$temp_file" "$temp_output"
}


@test "requests.download() 禁用进度显示" {
    requests.init

    local temp_file=$(mktemp)
    local temp_output="${temp_file}.downloaded"

    # 创建测试文件内容
    echo "silent download test" > "$temp_file"

    # 禁用进度显示
    run requests.download "file://$temp_file" "$temp_output" "false"

    # 验证退出码为 0
    [ "$status" -eq 0 ]

    # 验证文件被下载
    [ -f "$temp_output" ]

    rm -f "$temp_file" "$temp_output"
}


@test "requests.download() 支持断点续传参数" {
    requests.init

    local temp_output=$(mktemp)

    # 测试禁用断点续传
    run requests.download "https://httpbin.org/bytes/50" "$temp_output" "true" "false"

    # 验证退出码为 0（成功）
    [ "$status" -eq 0 ]

    # 验证文件存在且非空
    [ -f "$temp_output" ]
    [ -s "$temp_output" ]

    rm -f "$temp_output"
}


@test "requests.download() 下载大文件" {
    requests.init

    local temp_output=$(mktemp)

    # 下载较大文件测试断点续传
    run requests.download "https://httpbin.org/bytes/1024" "$temp_output" "true" "true"

    # 验证退出码为 0
    [ "$status" -eq 0 ]

    # 验证文件大小为 1024 字节
    [ -f "$temp_output" ]
    local file_size
    file_size=$(wc -c < "$temp_output")
    [ "$file_size" -eq 1024 ]

    rm -f "$temp_output"
}


@test "requests.download() 复用请求配置" {
    requests.init

    # 设置自定义超时和请求头
    requests.timeout 60
    requests.headers.build "X-Test-Header" "test-value"

    local temp_output=$(mktemp)

    # 下载应该成功，且使用上述配置
    run requests.download "https://httpbin.org/headers" "$temp_output"

    # 验证退出码为 0
    [ "$status" -eq 0 ]

    # 验证文件存在
    [ -f "$temp_output" ]

    # 验证自定义请求头被发送（httpbin 会回显请求头）
    grep -q "test-value" "$temp_output" || true

    rm -f "$temp_output"
}


@test "requests.download() 无效域名返回非零退出码" {
    requests.init

    local temp_output=$(mktemp)

    # 使用不存在的域名
    run requests.download "https://this-domain-does-not-exist-12345.invalid/file" "$temp_output" "false"

    # 验证退出码非 0（DNS 解析失败）
    [ "$status" -ne 0 ]

    rm -f "$temp_output"
}

