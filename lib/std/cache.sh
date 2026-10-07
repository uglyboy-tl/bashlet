#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016

# 通用 TTL 缓存：按「命名空间 + 键」把一段内容存到本地，TTL 内视为新鲜。
#
# 只做**存储与新鲜度判定**——「什么时候允许缓存、命中要不要打日志、失败要不要降级用旧值」
# 是调用方的策略（见 ext/requests.cache 的过期降级、各脚本自己的开关与 TTL 默认值）。
#
# 目录走 std/path:path.cache_dir，所以 SCRIPT_CACHE_DIR / XDG_CACHE_HOME 能覆盖；
# 命名空间落成子目录，互不干扰。键取哈希：优先 sha256sum，取不到退回 cksum。

import std/path

# [<ns>] → 缓存根目录（或根下的命名空间目录），按需创建；取不到目录返回非 0
#
# 不做「根目录取一次就记住」：调用方都是 `$(cache.dir ...)`，命令替换跑在子 shell 里，
# 函数内的赋值出不来——那个缓存从来就没生效过，留着只会误导。mkdir -p 本身很便宜。
cache.dir() {
	local dir
	dir="$(path.cache_dir)" || return 1
	mkdir -p "$dir" || return 1
	[[ -n ${1:-} ]] && dir="$dir/$1"
	mkdir -p "$dir" 2> /dev/null || return 1
	printf '%s' "$dir"
}

# <段...> → 定长键（内容相同则键相同；段序不同、段里含分隔符都不会撞）
cache.key() {
	local raw
	raw="$(printf '%s\0' "$@")"
	# 用内建判断，避免为一个哈希函数拖进 std/system
	if command -v sha256sum > /dev/null 2>&1; then
		printf '%s' "$raw" | sha256sum | cut -c1-40
	else
		# 没有 sha256sum 时退回 cksum；两段之间补个 -，别把「校验和 + 长度」粘成一个数
		printf '%s' "$raw" | cksum | tr -s ' ' '-'
	fi
}

# <ns> <键> → 文件路径（顺带创建目录；不判断存在与否）
cache.path() {
	local dir key="${2:-}"
	# 键正常来自上面的哈希函数（定长），但含 / 或 .. 的键会写到自己命名空间外面去
	[[ $key != */* && $key != *..* ]] || return 1
	dir="$(cache.dir "${1:-default}")" || return 1
	printf '%s/%s' "$dir" "$key"
}

# <文件> [<ttl 秒>] → 0=新鲜。文件不存在、ttl 非法或 <=0 都算不新鲜。
cache.fresh() {
	local file="$1" ttl="${2:-0}" mtime
	[[ -f $file ]] || return 1
	[[ $ttl =~ ^[0-9]+$ ]] || return 1
	((ttl > 0)) || return 1
	mtime=$(stat -c %Y "$file" 2> /dev/null) || mtime=$(stat -f %m "$file" 2> /dev/null) || return 1
	(($(date +%s) - mtime < ttl))
}

# <ns> <键> <内容> → 原子落盘（同目录临时文件 + mv，避免读到半截文件）。写失败返回非 0。
cache.put() {
	local f tmp
	f="$(cache.path "$1" "$2")" || return 1
	tmp="$f.$$"
	printf '%s' "${3:-}" > "$tmp" 2> /dev/null || {
		rm -f "$tmp"
		return 1
	}
	mv -f "$tmp" "$f" 2> /dev/null || {
		rm -f "$tmp"
		return 1
	}
}

# <ns> <键> [<ttl 秒>] → stdout 内容；缺失或过期返回非 0
cache.get() {
	local f
	f="$(cache.path "$1" "$2")" || return 1
	cache.fresh "$f" "${3:-0}" || return 1
	cat "$f"
}

# [<ns>] → 删掉整个命名空间（不给参数就是全部），调试与强制刷新用
cache.clear() {
	local dir
	dir="$(cache.dir "${1:-}")" || return 1
	rm -rf "$dir"
}
