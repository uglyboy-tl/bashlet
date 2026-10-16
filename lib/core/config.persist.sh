#!/usr/bin/env bash

import std/string
import std/fs
import core/log
import core/config

config.persist.update() {
	local _f _s _k _v _sec _sec_grep _pat _repl _n
	(($# % 2 == 1)) && _f="${!#}" && set -- "${@:1:$#-1}" || _f="$(config.path)"
	(($# == 2)) && { _v="$2" && [[ $1 == *.* ]] && _s="${1%%.*}" _k="${1#*.}" || _s="" _k="$1" && config.set "$@" || return $?; }
	(($# == 4)) && { _s="$1.$2" _k="$3" _v="$4" && config.array.set "$@" || return $?; }
	[[ ! -f $_f ]] && config.persist.save "$_f" && return 0

	# 值直接嵌进 TOML 双引号串，含引号或换行会把配置写坏；宁可 fail-loud 也不留半个坏文件
	[[ $_v == *'"'* || $_v == *$'\n'* ]] && {
		log.error "config value must not contain quote or newline: $_k"
		return 1
	}

	_sec="${_s:+[$_s]}"
	_sec_grep="$(string.escape.regex "${_sec}")"
	_pat="^${_k}[[:space:]]*=" _repl="${_k} = \"${_v}\""

	if [[ -n $_sec ]]; then
		_n=$(fs.find "$_f" "^${_sec_grep}$") || _n=""
		[[ -n $_n ]] && fs.find "$_f" "$_pat" "$_n" 1> /dev/null && fs.replace "$_f" "$_pat" "$_repl" "$_n" && return 0
	else
		fs.find "$_f" "$_pat" "" 1> /dev/null && fs.replace "$_f" "$_pat" "$_repl" "$_n" && return 0 || true
	fi
	[[ -n $_n ]] && { fs.insert "$_f" "^${_sec_grep}$" "$_repl" "0" && return 0; } || true
	{
		echo ""
		[[ -n $_s ]] && echo "$_sec"
		echo "$_repl"
	} >> "$_f"
}

# 删除整个 [section]（含其全部键）。section 不存在时返回 0（幂等）
# 纯文本删段，不解析 TOML：表头允许尾部空白与行内注释，也认数组表 `[[section]]`。
# 用法: config.persist.remove_section <section> [file]
config.persist.remove_section() {
	local _s="${1:-}" _f _tmp
	(($# >= 2)) && _f="$2" || _f="$(config.path)"
	[[ -n $_s && -f $_f ]] || return 0

	_tmp="$_f.tmp.$$"
	if awk -v s="[$_s]" '
		{ line = $0; sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line) }
		line == s || line == ("[" s "]") { skip = 1; next }
		substr(line, 1, length(s)) == s && substr(line, length(s) + 1, 1) ~ /[ \t#]/ { skip = 1; next }
		skip && line ~ /^\[/ { skip = 0 }
		!skip { print }
	' "$_f" > "$_tmp"; then
		mv "$_tmp" "$_f" && return 0
	fi
	rm -f "$_tmp"
	return 1
}

config.persist.save() {
	local _f="${1:-$(config.path)}" _k _v _s _field _arr _current _last=""
	local -a _top=() _other=() _o=()
	local _has_f_k=0 _has_f_a=0

	(($# >= 2)) && [[ -n $2 ]] && local -n _filter_keys="$2" && _has_f_k=1
	(($# >= 3)) && [[ -n $3 ]] && local -n _filter_arrays="$3" && _has_f_a=1

	for _k in "${!_CONFIG_VALUES[@]}"; do
		((_has_f_k)) && _s="${_k%.*}" && ! [[ -v "_CONFIG_ARRAY_REGISTERED[${_s%%.*}]" ]] && [[ " ${_filter_keys[*]} " != *" $_k "* ]] && continue
		[[ $_k =~ \. ]] && _other+=("$_k") || _top+=("$_k")
	done

	# shellcheck disable=SC2207
	IFS=$'\n' _other=($(sort <<< "${_other[*]}")) && unset IFS

	for _k in "${_top[@]}"; do
		[[ -v "_CONFIG_VALUES[$_k]" ]] && _o+=("$_k = \"${_CONFIG_VALUES[$_k]}\"")
	done

	for _k in "${_other[@]}"; do
		_v="${_CONFIG_VALUES[$_k]}"
		_s="${_k%.*}"
		_field="${_k##*.}"
		_arr="${_s%%.*}"

		if [[ -v "_CONFIG_ARRAY_REGISTERED[$_arr]" ]]; then
			[[ ! $_s =~ ^[^.]+\.[^.]+$ ]] && continue
			((_has_f_a)) && {
				[[ -v "_filter_arrays[$_arr]" ]] || continue
				[[ " ${_filter_arrays[$_arr]} " == *" $_field "* ]] || continue
			}
		fi

		_current="[$_s]"
		[[ $_current != "$_last" ]] && {
			[[ -n $_last || ${#_o[@]} -gt 0 ]] && _o+=("")
			_o+=("$_current")
			_last="$_current"
		}
		_o+=("$_field = \"$_v\"")
	done

	fs.write "$_f" "${_o[@]}"
}
