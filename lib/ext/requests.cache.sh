#!/usr/bin/env bash
# shellcheck disable=SC2016

import std/path
import core/log
import ext/requests

# HTTP 条件缓存：把 URL 的响应体缓存在本地，TTL 控制回源频率，
# ETag/Last-Modified 做条件请求——远端未变更时只刷新时间戳（304），不重复下载。
#
# 契约：与 requests 一致，调用前先 requests.init。
# 本模块会自行设置 If-None-Match / If-Modified-Since，调用方不要再设这两个头。

# 缓存文件路径（URL 哈希命名，换 URL 不会复用旧内容）
requests.cache.path() { printf '%s/http/%s' "$(path.cache_dir)" "$(printf '%s' "$1" | cksum | cut -d' ' -f1)"; }

# 缓存年龄是否小于 ttl 秒（ttl=0 恒为过期）
requests.cache.fresh() {
	local mtime ttl="${2:-0}"
	[[ -f $1 ]] || return 1
	[[ $ttl =~ ^[0-9]+$ ]] || ttl=0
	mtime=$(stat -c %Y "$1" 2> /dev/null) || mtime=$(stat -f %m "$1" 2> /dev/null) || return 1
	(($(date +%s) - mtime < ttl))
}

# 回源取内容：带验证器发条件请求，304 只 touch 缓存，2xx 覆盖缓存并记录验证器
# 返回 0=缓存可用，1=失败
requests.cache.fetch() {
	local url="$1" cache meta tmp response code etag modified
	cache=$(requests.cache.path "$url")
	meta="$cache.meta"
	tmp="$cache.tmp"
	mkdir -p "${cache%/*}"

	if [[ -f $cache && -f $meta ]]; then
		etag=$(sed -n 's/^etag=//p' "$meta")
		modified=$(sed -n 's/^last-modified=//p' "$meta")
		[[ -n $etag ]] && requests.headers.append "If-None-Match" "$etag"
		[[ -z $etag && -n $modified ]] && requests.headers.append "If-Modified-Since" "$modified"
	fi

	response=$(requests.get "$url") || return 1
	code=$(requests.status_code "$response")

	if [[ $code == "304" ]]; then
		touch "$cache"
		log.debug "requests.cache: 远端未变更 (304), 刷新本地时间戳"
		return 0
	fi
	[[ $(requests.success "$response") == "true" ]] || return 1

	requests.text "$response" > "$tmp" || return 1
	mv "$tmp" "$cache"
	{
		printf 'etag=%s\n' "$(requests.headers "$response" "ETag")"
		printf 'last-modified=%s\n' "$(requests.headers "$response" "Last-Modified")"
	} > "$meta"
	return 0
}

# 保证缓存可用：TTL 内零请求，过期才发条件请求；回源失败但有旧缓存时降级使用
# 结果通过 requests.cache.path "$url" 获取
requests.cache.ensure() {
	local url="$1" cache
	cache=$(requests.cache.path "$url")
	requests.cache.fresh "$cache" "${2:-0}" && return 0
	requests.cache.fetch "$url" && return 0
	[[ -f $cache ]] && log.warn "requests.cache: 回源失败，降级使用过期缓存 ($url)" && return 0
	log.error "requests.cache: 无可用缓存且回源失败 ($url)"
	return 1
}
