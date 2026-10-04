#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import ext/github
	log.setLevel INFO
	requests.init

	RELEASE_JSON='{
  "tag_name": "v1.2.3",
  "name": "1.2.3",
  "assets": [
    {"name": "app-linux-x86_64.tar.gz", "browser_download_url": "https://example.com/a"},
    {"name": "app-darwin-arm64.tar.gz", "browser_download_url": "https://example.com/b"}
  ]
}'
}

# ============ 纯解析（离线） ============

@test "github.release.version - 从 tag 提取 x.y.z" {
	run github.release.version "$RELEASE_JSON"
	assert_output "1.2.3"
}

@test "github.release.version - 无版本号时原样返回 tag" {
	run github.release.version '{"tag_name":"nightly"}'
	assert_output "nightly"
}

@test "github.asset.url - 按正则挑资产" {
	run github.asset.url "$RELEASE_JSON" 'linux.*x86_64'
	assert_output "https://example.com/a"
}

@test "github.asset.url - 忽略大小写" {
	run github.asset.url "$RELEASE_JSON" 'DARWIN'
	assert_output "https://example.com/b"
}

@test "github.asset.url - 无匹配返回失败" {
	run github.asset.url "$RELEASE_JSON" 'windows'
	assert_failure
}

# ============ 资产名匹配（占位符与架构别名） ============

@test "github.asset.arch_regex - 已知架构展开为多种写法" {
	run github.asset.arch_regex amd64
	[[ $output == *x86_64* && $output == *amd64* ]]

	run github.asset.arch_regex arm64
	[[ $output == *aarch64* && $output == *arm64* ]]
}

@test "github.asset.arch_regex - 未知架构回退为原值" {
	run github.asset.arch_regex riscv64
	[ "$output" = "riscv64" ]
}

@test "github.asset.pattern - 展开 {os}/{arch} 与通配符" {
	run github.asset.pattern 'app-{os}-{arch}*'
	assert_success
	[ "$output" = "app-$(system.os)-$(github.asset.arch_regex "$(system.arch)").*$" ]
}

@test "github.asset.pattern - 带扩展名时要求以该扩展名结尾" {
	run github.asset.pattern 'app-{os}' tar.gz
	[[ $output == *"[.][^.]*tar.gz$" ]]
}

@test "github.raw.url - 默认用 HEAD" {
	run github.raw.url "a/b" "registry.toml"
	assert_output "https://github.com/a/b/raw/HEAD/registry.toml"
}

@test "github.raw.url - 指定 ref" {
	run github.raw.url "a/b" "path/x.toml" "v1"
	assert_output "https://github.com/a/b/raw/v1/path/x.toml"
}

# ============ 镜像前缀改写 ============

@test "github.url.proxied - 空前缀原样返回" {
	run github.url.proxied "https://github.com/a/b/x" ""
	assert_output "https://github.com/a/b/x"
}

@test "github.url.proxied - github.com 直链改写" {
	run github.url.proxied "https://github.com/a/b/releases/download/v1/x.tar.gz" "https://p/gh/"
	assert_output "https://p/gh/a/b/releases/download/v1/x.tar.gz"
}

@test "github.url.proxied - raw 域名转成 /raw/ 形式" {
	run github.url.proxied "https://raw.githubusercontent.com/a/b/main/dir/x.toml" "https://p/gh/"
	assert_output "https://p/gh/a/b/raw/main/dir/x.toml"
}

@test "github.url.proxied - 非 GitHub 域名原样返回" {
	run github.url.proxied "https://example.com/x" "https://p/gh/"
	assert_output "https://example.com/x"
}

# ============ 网络层（桩） ============

@test "github.release.latest - 非 2xx 返回失败" {
	requests.get() { echo '{"status_code":404,"success":false,"headers":{},"body":""}'; }

	run github.release.latest "a/b"
	assert_failure
}

@test "github.release.latest - 2xx 返回 release JSON" {
	local body
	body=$(printf '%s' "$RELEASE_JSON" | base64 -w0)
	requests.get() { printf '{"status_code":200,"success":true,"headers":{},"body":"%s"}' "$body"; }

	run github.release.latest "a/b"
	assert_success

	run github.release.version "$output"
	assert_output "1.2.3"
}

@test "github.release.first - 取列表首条" {
	local body
	body=$(printf '[{"tag_name":"v9.9.9","assets":[]}]' | base64 -w0)
	requests.get() { printf '{"status_code":200,"success":true,"headers":{},"body":"%s"}' "$body"; }

	run github.release.first "a/b"
	assert_success

	run github.release.version "$output"
	assert_output "9.9.9"
}

@test "github.release.pick - 输出 VERSION|||URL" {
	local body
	body=$(printf '%s' "$RELEASE_JSON" | base64 -w0)
	requests.get() { printf '{"status_code":200,"success":true,"headers":{},"body":"%s"}' "$body"; }

	run github.release.pick "a/b" 'linux.*x86_64'
	assert_success
	assert_output "1.2.3|||https://example.com/a"
}

@test "github.release.pick - 资产无匹配返回失败" {
	local body
	body=$(printf '%s' "$RELEASE_JSON" | base64 -w0)
	requests.get() { printf '{"status_code":200,"success":true,"headers":{},"body":"%s"}' "$body"; }

	run github.release.pick "a/b" 'windows'
	assert_failure
}

@test "github.release.pick - API 失败返回失败" {
	requests.get() { echo '{"status_code":404,"success":false,"headers":{},"body":""}'; }

	run github.release.pick "a/b" '.*'
	assert_failure
}

@test "github.contents.list - 列出目录下的文件名" {
	local body
	body=$(printf '[
  {"name":"a.sh","type":"file"},
  {"name":"b.sh","type":"file"},
  {"name":"sub","type":"dir"}
]' | base64 -w0)
	requests.get() { printf '{"status_code":200,"success":true,"headers":{},"body":"%s"}' "$body"; }

	run github.contents.list "a/b" "scripts"
	assert_success
	assert_line --index 0 "a.sh"
	assert_line --index 1 "b.sh"
	assert_line --index 2 "sub"
}

@test "github.contents.list - API 失败返回失败" {
	requests.get() { echo '{"status_code":404,"success":false,"headers":{},"body":""}'; }

	run github.contents.list "a/b" "scripts"
	assert_failure
}
