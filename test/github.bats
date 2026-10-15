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

@test "github.asset.url - 多命中时按名称排序取第一个，不依赖资产顺序" {
	# 回归点：资产顺序由上传决定、GitHub 不承诺；候选用反字典序排列，仍应拿到 gnu
	run github.asset.url '{
  "assets": [
    {"name": "app-linux-musl.tar.gz", "browser_download_url": "https://example.com/musl"},
    {"name": "app-linux-gnu.tar.gz", "browser_download_url": "https://example.com/gnu"}
  ]
}' 'app-linux'
	assert_output "https://example.com/gnu"
}

@test "github.asset.url - 纯正版胜过 -variant 后缀变体" {
	# 回归点：ASCII 里 `-`(0x2D) < `.`(0x2E)，纯按名称字典序会挑到 -static；按「长度 → 名称」则纯正版胜
	run github.asset.url '{
  "assets": [
    {"name": "app-linux-gnu-static.tar.gz", "browser_download_url": "https://example.com/static"},
    {"name": "app-linux-gnu.tar.gz", "browser_download_url": "https://example.com/plain"}
  ]
}' 'app-linux'
	assert_output "https://example.com/plain"
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

@test "github.asset.libc_regex - 展开为可选的风味集" {
	run github.asset.libc_regex
	assert_output '(-gnueabihf|-musleabihf|-musleabi|-softfloat|-glibc|-gnu|-musl)?'
}

@test "github.asset.pattern - {libc} 展开且 ? 量词不被当成通配符" {
	run github.asset.pattern 'app-{os}{libc}' tar.gz
	assert_success
	# 回归点：{libc} 必须在 ? → . 之后展开，否则原本可选的 (…)? 会变成必匹配一个字符的 (…).
	assert_output "app-$(system.os)$(github.asset.libc_regex)[.][^.]*tar.gz$"
}

@test "github.asset.pattern - {libc} 同时匹配带风味与不带风味的资产名" {
	run github.asset.pattern 'app-{os}{libc}' tar.gz
	local p="$output"
	echo "app-linux-gnu.tar.gz" | grep -qiE -- "$p"
	echo "app-linux-gnueabihf.tar.gz" | grep -qiE -- "$p"
	echo "app-linux-musleabihf.tar.gz" | grep -qiE -- "$p"
	echo "app-linux-musl.tar.gz" | grep -qiE -- "$p"
	echo "app-linux.tar.gz" | grep -qiE -- "$p"
	! echo "app-darwin-gnu.tar.gz" | grep -qiE -- "$p"
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

@test "github.url.insteadof - 按 git 配置替换前缀" {
	git() { printf 'url.https://gh-proxy.com/https://github.com/.insteadof https://github.com/\n'; }

	run github.url.insteadof "https://github.com/a/b/releases/download/v1/x.tar.gz"
	assert_output "https://gh-proxy.com/https://github.com/a/b/releases/download/v1/x.tar.gz"
}

@test "github.url.insteadof - 最长前缀优先" {
	git() { printf 'url.https://short/.insteadof https://\nurl.https://long/https://github.com/.insteadof https://github.com/\n'; }

	run github.url.insteadof "https://github.com/a/b"
	assert_output "https://long/https://github.com/a/b"
}

@test "github.url.insteadof - 未命中或 git/config 缺失时原样返回" {
	git() { return 1; }
	run github.url.insteadof "https://github.com/a/b"
	assert_output "https://github.com/a/b"
}

@test "github.url.insteadof - 读真实 git 配置" {
	export HOME="$BATS_TEST_TMPDIR/home" GIT_CONFIG_NOSYSTEM=1
	mkdir -p "$HOME"
	printf '[url "https://gh-proxy.com/https://github.com/"]\n\tinsteadOf = https://github.com/\n' > "$HOME/.gitconfig"

	run github.url.insteadof "https://github.com/a/b/x"
	assert_output "https://gh-proxy.com/https://github.com/a/b/x"
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
