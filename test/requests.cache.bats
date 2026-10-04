#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import ext/requests.cache
	log.setLevel INFO
	requests.init

	export SCRIPT_CACHE_DIR="$BATS_TEST_TMPDIR/http-cache"
	URL="https://example.com/data.toml"

	# 完全离线的 HTTP 桩：所有分支都不触网
	requests.get() { echo "STUB"; }
	requests.status_code() { echo "${STUB_CODE:-200}"; }
	requests.success() { [[ ${STUB_CODE:-200} == "200" ]] && echo true || echo false; }
	requests.text() { echo "${STUB_BODY:-}"; }
	requests.headers() { [[ ${2:-} == "ETag" ]] && echo "${STUB_ETAG:-}" || echo "${STUB_MODIFIED:-}"; }
	requests.headers.append() { :; }
}

teardown() {
	unset STUB_CODE STUB_BODY STUB_ETAG STUB_MODIFIED 2> /dev/null || true
}

@test "requests.cache.path - 同 URL 稳定，不同 URL 不同" {
	local p1 p2 p3
	p1=$(requests.cache.path "$URL")
	p2=$(requests.cache.path "$URL")
	p3=$(requests.cache.path "https://example.com/other.toml")
	[ "$p1" = "$p2" ]
	[ "$p1" != "$p3" ]
}

@test "requests.cache.fresh - TTL 内为真，TTL=0 为假" {
	local cache
	cache=$(requests.cache.path "$URL")
	mkdir -p "${cache%/*}"
	echo hi > "$cache"

	run requests.cache.fresh "$cache" 60
	assert_success

	run requests.cache.fresh "$cache" 0
	assert_failure
}

@test "requests.cache.fresh - 缓存不存在为假" {
	run requests.cache.fresh "$(requests.cache.path "$URL")" 60
	assert_failure
}

@test "requests.cache.fetch - 200 写入内容与验证器" {
	export STUB_CODE=200 STUB_BODY="hello" STUB_ETAG='"abc"'
	local cache
	cache=$(requests.cache.path "$URL")

	run requests.cache.fetch "$URL"
	assert_success

	run cat "$cache"
	assert_output "hello"

	run grep -q '^etag="abc"$' "$cache.meta"
	assert_success
}

@test "requests.cache.fetch - 304 只刷新时间戳，不覆盖内容" {
	export STUB_CODE=304
	local cache
	cache=$(requests.cache.path "$URL")
	mkdir -p "${cache%/*}"
	echo old > "$cache"
	printf 'etag="abc"\n' > "$cache.meta"
	touch -d '2 hours ago' "$cache"

	run requests.cache.fetch "$URL"
	assert_success

	run cat "$cache"
	assert_output "old"

	run requests.cache.fresh "$cache" 60
	assert_success
}

@test "requests.cache.fetch - 非 2xx 返回失败" {
	export STUB_CODE=404

	run requests.cache.fetch "$URL"
	assert_failure
}

@test "requests.cache.ensure - TTL 内不回源" {
	export STUB_CODE=500
	local cache
	cache=$(requests.cache.path "$URL")
	mkdir -p "${cache%/*}"
	echo cached > "$cache"

	run requests.cache.ensure "$URL" 60
	assert_success
}

@test "requests.cache.ensure - 回源失败时降级使用过期缓存" {
	export STUB_CODE=500
	local cache
	cache=$(requests.cache.path "$URL")
	mkdir -p "${cache%/*}"
	echo cached > "$cache"

	run requests.cache.ensure "$URL" 0
	assert_success

	run cat "$cache"
	assert_output "cached"
}

@test "requests.cache.ensure - 无缓存且回源失败时报错" {
	export STUB_CODE=500

	run requests.cache.ensure "$URL" 0
	assert_failure
}
