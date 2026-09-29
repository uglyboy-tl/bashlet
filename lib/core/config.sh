#!/usr/bin/env bash

import std/array
import std/map
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

# 内部：关联数组 $1 的 key $2 对应的空格分隔列表是否含 token $3（拆成数组后复用 array.contains）
_config.list.contains() {
	local -n _ref="$1"
	local -a _t=()
	read -ra _t <<< "${_ref[$2]:-}" || true
	array.contains _t "${3:-}"
}

config.array.has() {
	map.contains _CONFIG_ARRAY_REGISTERED "$1" || return 1
	(($# >= 2)) && _config.list.contains _CONFIG_ARRAY_ITEMS "$1" "$2" || (($# < 2)) || return 1
	(($# >= 3)) && _config.list.contains _CONFIG_ARRAY_REGISTERED "$1" "$3" || (($# < 3)) || return 1
}

config.array.get() { [[ -v "_CONFIG_VALUES["$1.$2.$3"]" ]] && echo "${_CONFIG_VALUES["$1.$2.$3"]}" || return 1; }

config.array.add() {
	_config.list.contains _CONFIG_ARRAY_ITEMS "$1" "$2" && return 0
	_CONFIG_ARRAY_ITEMS["$1"]+=" $2"
}

config.array.set() {
	! config.array.has "$1" && {
		log.error "未注册的数组配置名: $1"
		return 1
	}
	_config.list.contains _CONFIG_ARRAY_REGISTERED "$1" "$3" || {
		log.error "未注册的数组配置项: $1:$3"
		return 1
	}
	config.array.add "$1" "$2"
	_CONFIG_VALUES["$1.$2.$3"]=$4
}

config.type() { [[ -v "_CONFIG_TYPES[$1]" ]] && echo "${_CONFIG_TYPES[$1]}"; }

config.desc() { [[ -v "_CONFIG_DESCS[$1]" ]] && echo "${_CONFIG_DESCS[$1]}"; }
