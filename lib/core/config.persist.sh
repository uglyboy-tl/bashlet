#!/usr/bin/env bash

import std/string
import std/fs
import core/config

config.persist.update() {
	local _f _s _k _v _sec _sec_grep _pat _repl _n
	(($# % 2 == 1)) && _f="${!#}" && set -- "${@:1:$#-1}" || _f="$(config.path)"
	(($# == 2)) && { _v="$2" && [[ $1 == *.* ]] && _s="${1%%.*}" _k="${1#*.}" || _s="" _k="$1" && config.set "$@" || return $?; }
	(($# == 4)) && { _s="$1.$2" _k="$3" _v="$4" && config.array.set "$@" || return $?; }
	[[ ! -f $_f ]] && config.persist.save "$_f" && return 0

	_sec="${_s:+[$_s]}"
	_sec_grep="$(string.escape.regex "${_sec}")"
	_pat="^${_k}[[:space:]]*=" _repl="${_k} = \"${_v}\""

	# 优先使用 mikefarah/yq 做原生 TOML 更新
	config.persist._yq_try "$_f" "$_s" "$_k" "$_v" && return 0

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

# 内部：尝试用 yq 更新文件，不适合/失败时返回 1 走原生逻辑
config.persist._yq_try() {
	local _f="$1" _s="$2" _k="$3" _v="$4"
	command -v yq &>/dev/null || return 1
	yq --version 2>&1 | grep -qi "mikefarah" || return 1

	# section 头不存在时走原生逻辑（避免 yq 输出内联表）
	if [[ -n $_s ]]; then
		grep -q "^\[${_s}\]" "$_f" 2>/dev/null || return 1
	fi

	local _expr
	if [[ -z $_s ]]; then
		_expr=".${_k} = \"${_v}\""
	elif [[ $_s == *.* ]]; then
		local _a="${_s%%.*}" _i="${_s#*.}"
		_expr=".${_a}.\"${_i}\".${_k} = \"${_v}\""
	else
		_expr=".${_s}.${_k} = \"${_v}\""
	fi

	yq -o toml -i "$_expr" "$_f" 2>/dev/null
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
