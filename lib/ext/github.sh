#!/usr/bin/env bash
# shellcheck disable=SC2016

import std/system
import core/log
import ext/requests

# GitHub API 薄封装：release 查询、资产名匹配、内容列出、raw URL。
# HTTP 细节交给 ext/requests，缓存交给 ext/requests.cache。
#
# 网络与解析分离：release.latest/first/pick、contents.list 触网；
# version、asset.url 是纯解析函数，因此后者可以离线测试。
#
# 契约：与 ext/requests 一致，调用前先 requests.init（解析函数依赖它定位 jq）。
# GITHUB_TOKEN 存在时，只有 github.api 会附加认证头；raw / 下载请求不带 token。

declare -g _GITHUB_API="https://api.github.com"
declare -g _GITHUB_WEB="https://github.com"

# 调 GitHub API，返回 requests 响应包裹（用 requests.json / requests.text 处理结果）
# 认证头只在这里附加：带 token 的请求不应该发给镜像代理或 raw 域名
github.api() {
	[[ -n ${GITHUB_TOKEN:-} ]] && requests.headers.append "Authorization" "token $GITHUB_TOKEN"
	requests.get "$_GITHUB_API/$1"
}

# 响应包裹 → JSON 文本；非 2xx 或空响应返回 1
github._json() {
	local response="$1" filter="${2:-.}"
	[[ -n $response ]] || return 1
	[[ $(requests.success "$response") == "true" ]] || {
		log.debug "github: HTTP $(requests.status_code "$response")"
		return 1
	}
	requests.json "$response" "$filter"
}

# ===== Release =====

# 最新正式 release 的 JSON
github.release.latest() { github._json "$(github.api "repos/$1/releases/latest")"; }

# 最近的 release（可能含预发布）的 JSON
github.release.first() { github._json "$(github.api "repos/$1/releases")" ".[0]"; }

# 从 release JSON 提取版本号：优先取 tag 里的 x.y.z，取不到则原样返回 tag
github.release.version() {
	local tag
	tag=$("$_REQUESTS_JQ" -r '.tag_name // .name // ""' <<< "$1")
	[[ $tag =~ ([0-9]+\.[0-9]+(\.[0-9]+)?) ]] && echo "${BASH_REMATCH[1]}" || echo "$tag"
}

# 一步取「版本 + 下载 URL」：输出 VERSION|||URL，失败返回 1
# mode=stable 取最新正式 release，其它值取最近的 release（可能含预发布）
# pattern 的写法见 github.asset.pattern
github.release.pick() {
	local repo="$1" pattern="$2" mode="${3:-stable}"
	local json version url

	if [[ $mode == "stable" ]]; then
		json=$(github.release.latest "$repo") || return 1
	else
		json=$(github.release.first "$repo") || return 1
	fi

	version=$(github.release.version "$json")
	url=$(github.asset.url "$json" "$pattern") || return 1
	[[ -n $version && -n $url ]] || return 1

	printf '%s|||%s\n' "$version" "$url"
}

# ===== 资产名匹配 =====
# {os}/{arch} 占位符与架构别名表是「挑 release 资产」的知识，与 release 查询同居一处
# （模块边界由载荷约束决定，见 bashlet docs/adr/0001-payload-constraint-module-boundaries.md）

# 归一架构名 → 发布资产常见写法的正则；未知架构原样返回
github.asset.arch_regex() {
	local arch="${1:-$(system.arch)}"
	case "$arch" in
		amd64) echo "(x86_64|x64|amd64)" ;;
		arm64) echo "(aarch64|arm64)" ;;
		armhf) echo "(armv7l|armhf|armv7hl|armv7l-unknown)" ;;
		i386) echo "(i686|i386|i586)" ;;
		*) echo "$arch" ;;
	esac
}

# 资产文件名模式 → 正则：展开 {os}/{arch} 占位符，通配符 * → .*、? → .
# ext 非空时要求文件名以 .<ext> 结尾（如 ext=tar.gz 匹配 .tar.gz）
github.asset.pattern() {
	local pattern="${1//\{os\}/$(system.os)}"
	pattern="${pattern//\{arch\}/$(github.asset.arch_regex "$(system.arch)")}"
	pattern="${pattern//\*/.*}"
	pattern="${pattern//\?/.}"
	[[ -n ${2:-} ]] && echo "${pattern}[.][^.]*${2}$" || echo "${pattern}$"
}

# 从 release JSON 按资产名正则挑下载 URL（忽略大小写），无匹配返回 1
github.asset.url() {
	local url
	url=$("$_REQUESTS_JQ" -r --arg pat "$2" 'first(.assets[]? | select(.name | test($pat; "i")) | .browser_download_url) // ""' <<< "$1")
	[[ -n $url && $url != "null" ]] && echo "$url"
}

# ===== 内容 =====

# 列出仓库某目录下的文件名（contents API，一行一个；不分页，超过 100 项只返回前 100）
github.contents.list() {
	local response
	response=$(github.api "repos/$1/contents/${2:-}?per_page=100") || return 1
	github._json "$response" '.[].name'
}

# raw 文件 URL；ref 省略时用 HEAD（GitHub 的默认分支别名）
github.raw.url() { printf '%s/%s/raw/%s/%s' "$_GITHUB_WEB" "$1" "${3:-HEAD}" "$2"; }

# 把 GitHub URL 改写为镜像前缀形式（大陆访问 GitHub 的常用做法）
# 支持两种形态，其余域名或空前缀一律原样返回：
#   https://github.com/OWNER/REPO/...                     → PREFIX/OWNER/REPO/...
#   https://raw.githubusercontent.com/OWNER/REPO/REF/...  → PREFIX/OWNER/REPO/raw/REF/...
github.url.proxied() {
	local url="$1" prefix="${2:-}" owner repo rest
	[[ -n $prefix ]] || {
		printf '%s' "$url"
		return 0
	}

	case "$url" in
		https://github.com/*) printf '%s' "$prefix${url#https://github.com/}" ;;
		https://raw.githubusercontent.com/*)
			rest="${url#https://raw.githubusercontent.com/}"
			owner="${rest%%/*}"
			rest="${rest#*/}"
			repo="${rest%%/*}"
			rest="${rest#*/}"
			printf '%s%s/%s/raw/%s' "$prefix" "$owner" "$repo" "$rest"
			;;
		*) printf '%s' "$url" ;;
	esac
}
