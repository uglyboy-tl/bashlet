#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	# 每个用例用独立的缓存根，别碰开发机真实的 ~/.cache
	unset SCRIPT_CACHE_DIR
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/xdg-cache"
	import std/cache
}

# ========== cache.dir / cache.path ==========

@test "cache.dir - 按需创建，带命名空间时是子目录" {
	local root ns
	root="$(cache.dir)"
	[ -d "$root" ]
	[ "$root" = "$BATS_TEST_TMPDIR/xdg-cache/$(path.script_name)" ]

	ns="$(cache.dir demo)"
	[ -d "$ns" ]
	[ "$ns" = "$root/demo" ]
}

@test "cache.dir - SCRIPT_CACHE_DIR 优先" {
	export SCRIPT_CACHE_DIR="$BATS_TEST_TMPDIR/override"
	[ "$(cache.dir)" = "$BATS_TEST_TMPDIR/override" ]
}

@test "cache.path - 落在 <根>/<ns>/<键>" {
	local p
	p="$(cache.path demo k1)"
	[ "$p" = "$BATS_TEST_TMPDIR/xdg-cache/$(path.script_name)/demo/k1" ]
}

# ========== cache.key ==========

@test "cache.key - 输入相同则键相同，不同则不同（且与段序有关）" {
	[ "$(cache.key a b c)" = "$(cache.key a b c)" ]
	[ "$(cache.key a b c)" != "$(cache.key a b d)" ]
	[ "$(cache.key a b c)" != "$(cache.key a c b)" ]
	[ -n "$(cache.key '')" ]
}

# ========== put / get ==========

@test "cache.put / cache.get - 往返内容一致，只按 TTL 判断" {
	cache.put demo k1 'hello 世界'
	run cache.get demo k1 60
	assert_success
	assert_output 'hello 世界'
}

@test "cache.get - 缺 ttl 或 ttl=0 视为过期，返回非 0" {
	cache.put demo k2 'x'
	run cache.get demo k2
	assert_failure
	run cache.get demo k2 0
	assert_failure
}

@test "cache.get - 未写过的键返回非 0" {
	run cache.get demo nope 60
	assert_failure
}

@test "cache.get - 超过 TTL 返回非 0" {
	cache.put demo k3 'old'
	touch -d '2 hours ago' "$(cache.path demo k3)"
	run cache.get demo k3 60
	assert_failure
	run cache.get demo k3 10800
	assert_success
}

@test "cache.put - 覆盖写不会留下临时文件" {
	cache.put demo k4 'first'
	cache.put demo k4 'second'
	run cache.get demo k4 60
	assert_output 'second'
	# 目录里只有键文件本身
	[ "$(find "$BATS_TEST_TMPDIR/xdg-cache/$(path.script_name)/demo" -mindepth 1 | wc -l)" -eq 1 ]
}

# ========== cache.fresh ==========

@test "cache.fresh - ttl 非法或 <=0 一律不新鲜" {
	cache.put demo k5 'x'
	local f
	f="$(cache.path demo k5)"
	run cache.fresh "$f" abc
	assert_failure
	run cache.fresh "$f" 0
	assert_failure
	run cache.fresh "$f" 60
	assert_success
}

@test "cache.fresh - 文件不存在为假" {
	run cache.fresh "$(cache.path demo missing)" 60
	assert_failure
}

# ========== cache.clear ==========

@test "cache.clear - 只删指定命名空间" {
	cache.put a k '1'
	cache.put b k '2'
	cache.clear a
	run cache.get a k 60
	assert_failure
	run cache.get b k 60
	assert_success
}

@test "cache.clear - 不带参数清空整个根" {
	cache.put a k '1'
	cache.clear
	run cache.get a k 60
	assert_failure
}

@test "路径函数 - 越界键被拒（含 / 或 ..）" {
	run cache.path demo "../escape"
	assert_failure
	run cache.path demo "a/b"
	assert_failure
	run cache.path demo "$(cache.key x)"
	assert_success
}

@test "键函数 - 段里含分隔符也不会与多段调用撞键" {
	[ "$(cache.key a b)" != "$(cache.key "$(printf 'a\nb')")" ]
	[ "$(cache.key a b)" != "$(cache.key b a)" ]
}
