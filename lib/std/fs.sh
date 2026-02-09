#!/usr/bin/env bash

import std/string

fs.file.exists() { [[ -f "$1" ]]; }

fs.dir.exists() { [[ -d "$1" ]]; }

fs.write() {
	local _f="$1"
	shift
	(($# > 0)) && printf "%s\n" "$@" >"$_f" || : >"$_f"
}

fs.find() { local _n=$(awk -v s="${3:-1}" -v p="$2" 'NR>=s && $0~p{print NR; exit}' "$1" 2>/dev/null) && [[ $_n ]] && echo "$_n" || return 1; }

fs.replace() {
	local _repl=$(string.escape.sed "$3")
	[[ -n "${4:-}" ]] && sed -i "${4},/$2/{/$2/{s|.*|$_repl|}}" "$1" || sed -i "/$2/{s|.*|$_repl|}" "$1"
}

fs.insert() { sed -i "/$2/a\\$3" "$1" 2>/dev/null; }

fs.rmline() { [[ -n "$4" ]] && sed -i "${4},/$2/{/$2/d}" "$1" 2>/dev/null || sed -i "/$2/d" "$1" 2>/dev/null; }

fs.cleanup() { ls -t ${1}* 2>/dev/null | tail -n +$((${2:-3} + 1)) | xargs -r rm -f; } # 保留最新的 n 个文件 (默认 3 个)

fs.mktemp() { mktemp 2>/dev/null || { log.error "Failed to create temporary file" && return 1; }; }
