#!/usr/bin/env bash

import std/array
import std/map
import std/fs
import std/path
import core/log

declare -ga _CONFIG_REGISTERED=()
declare -gA _CONFIG_ARRAY_REGISTERED=()
declare -gA _CONFIG_ARRAY_ITEMS=()
declare -gA _CONFIG_VALUES=()
declare -gA _CONFIG_TYPES=()
declare -gA _CONFIG_DESCS=()
declare -gi _CONFIG_STRICT_MODE=1

config.path() {
	[[ -n ${_CONFIG_PATH+x} ]] && echo "$_CONFIG_PATH" && return 0
	local _f="config.toml"
	[[ -f $_f ]] && echo "$_f" && return 0
	_f="$(path.config_dir)/config.toml"
	[[ -f $_f ]] && echo "$_f" && return 0
	log.error "配置文件不存在: $_f"
	return 1
}

config.register() {
	array.contains _CONFIG_REGISTERED "$1" && log.warn "Key $1 重复定义" || _CONFIG_REGISTERED+=("$1")
	_CONFIG_TYPES["$1"]="${3:-string}"
	_CONFIG_DESCS["$1"]="${4:-}"
	(($# >= 2)) && _CONFIG_VALUES["$1"]="$2" || true
}

config.array.register() {
	_CONFIG_ARRAY_REGISTERED["$1"]+=" $2"
	config.register "$1.$2" "${@:3}"
	unset '_CONFIG_REGISTERED[-1]'
}
config.loose() { _CONFIG_STRICT_MODE=0; }

config.load() {
	local _f="${1:-$(config.path)}" _in_arr=false _table=""
	[[ -z $_f ]] && return 1

	while IFS= read -r line || [[ -n $line ]]; do
		[[ $line =~ ^[[:space:]]*$ ]] && continue
		[[ $line =~ ^[[:space:]]*# ]] && continue

		if [[ $line =~ ^\[([^\]]+)\]$ ]]; then
			_table="${BASH_REMATCH[1]}"
			_in_arr=false
			if [[ $_table =~ ^([^.]+)\.(.+)$ ]]; then
				local _arr="${BASH_REMATCH[1]}" _itm="${BASH_REMATCH[2]}"
				! ((_CONFIG_STRICT_MODE)) || config.array.has "$_arr" && config.array.add "$_arr" "$_itm" && _in_arr=true
			fi
			continue
		fi

		[[ $line =~ ^([^=[:space:]]+)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
		local _ak="${BASH_REMATCH[1]}"
		local _k="${_table:+$_table.}$_ak" _v="${BASH_REMATCH[2]}"
		((_CONFIG_STRICT_MODE)) && [[ $_in_arr != "true" ]] && { array.contains "_CONFIG_REGISTERED" "$_k" || continue; }
		((_CONFIG_STRICT_MODE)) && [[ $_in_arr == "true" ]] && { config.array.has "$_arr" "$_itm" "$_ak" || continue; }

		_v="${_v%"${_v##*[![:space:]]}"}"
		[[ $_v =~ ^[\'\"](.*)[\'\"]$ ]] && _v="${BASH_REMATCH[1]}"
		_CONFIG_VALUES["$_k"]="$_v"
	done < "$_f"
}

config.keys() { printf "%s\n" "${_CONFIG_REGISTERED[@]}"; }

config.has() { [[ -v "_CONFIG_VALUES[$1]" ]]; }

config.get() { [[ -v "_CONFIG_VALUES[$1]" ]] && echo "${_CONFIG_VALUES[$1]}" || return 1; }

config.set() {
	! array.contains "_CONFIG_REGISTERED" "$1" && {
		log.error "未注册的配置项: $1"
		return 1
	}
	_CONFIG_VALUES["$1"]="$2"
}

config.sections() {
	local prefix="${1:-}"
	local -A seen=()
	local key section_prefix="${prefix:+$prefix.}"

	for key in "${!_CONFIG_VALUES[@]}"; do
		[[ $key == ${section_prefix}*.* ]] && {
			local part=${key#"$section_prefix"}
			seen["${part%%.*}"]=1
		}
	done

	printf "%s\n" "${!seen[@]}"
}

config.array.items() { [[ -v "_CONFIG_ARRAY_ITEMS[$1]" ]] && echo "${_CONFIG_ARRAY_ITEMS[$1]}"; }

config.array.has() {
	map.contains _CONFIG_ARRAY_REGISTERED "$1" || return 1
	(($# >= 2)) && [[ " ${_CONFIG_ARRAY_ITEMS[$1]:-} " == *" ${2:-} "* ]] || (($# < 2)) || return 1
	(($# >= 3)) && array.contains _CONFIG_ARRAY_REGISTERED "$3" || (($# < 3)) || return 1
}

config.array.get() { [[ -v "_CONFIG_VALUES["$1.$2.$3"]" ]] && echo "${_CONFIG_VALUES["$1.$2.$3"]}" || return 1; }

config.array.add() { [[ " ${_CONFIG_ARRAY_ITEMS[$1]:-} " != *" ${2:-} "* ]] && _CONFIG_ARRAY_ITEMS["$1"]+=" $2" || return 0; }

config.array.set() {
	! config.array.has "$1" && {
		log.error "未注册的数组配置名: $1"
		return 1
	}
	! array.contains _CONFIG_ARRAY_REGISTERED "${3-}" && {
		log.error "未注册的数组配置项: $1:$3"
		return 1
	}
	config.array.add "$1" "$2"
	_CONFIG_VALUES["$1.$2.$3"]=$4
}

config.type() { [[ -v "_CONFIG_TYPES[$1]" ]] && echo "${_CONFIG_TYPES[$1]}"; }

config.desc() { [[ -v "_CONFIG_DESCS[$1]" ]] && echo "${_CONFIG_DESCS[$1]}"; }

config.update() {
	local _f _s _k _v _sec _sec_grep _pat _repl _n
	(($# % 2 == 1)) && _f="${!#}" && set -- "${@:1:$#-1}" || _f="$(config.path)"
	(($# == 2)) && { _v="$2" && [[ $1 == *.* ]] && _s="${1%%.*}" _k="${1#*.}" || _s="" _k="$1" && config.set "$@" || return $?; }
	(($# == 4)) && { _s="$1.$2" _k="$3" _v="$4" && config.array.set "$@" || return $?; }
	[[ ! -f $_f ]] && config.save "$_f" && return 0

	_sec="${_s:+[$_s]}"
	_sec_grep="$(string.escape.regex "${_sec}")"
	_pat="^${_k}[[:space:]]*=" _repl="${_k} = \"${_v}\""

	# 优先使用 mikefarah/yq 做原生 TOML 更新
	config._yq_try "$_f" "$_s" "$_k" "$_v" && return 0

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
config._yq_try() {
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

config.save() {
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
