#!/usr/bin/env bash

import std/array
import std/map
import std/fs
import core/path
import core/log

declare -ga _CONFIG_REGISTERED=()
declare -gA _CONFIG_ARRAY_REGISTERED=()
declare -gA _CONFIG_ARRAY_ITEMS=()
declare -gA _CONFIG_VALUES=()
declare -gA _CONFIG_TYPES=()
declare -gA _CONFIG_DESCS=()

config.path() {
	[[ -n ${_CONFIG_PATH+x} ]] && echo "$_CONFIG_PATH" && return 0
	local _f="config.toml"
	[[ -f "$_f" ]] && echo "$_f" && return 0
	_f="$(path.config_dir)/config.toml"
	[[ -f "$_f" ]] && echo "$_f" && return 0
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

config.load() {
	local _f="${1:-$(config.path)}" _in_arr=false _table=""

	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^[[:space:]]*$ ]] && continue
		[[ "$line" =~ ^[[:space:]]*# ]] && continue

		if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
			_table="${BASH_REMATCH[1]}"
			_in_arr=false
			if [[ "$_table" =~ ^([^.]+)\.(.+)$ ]]; then
				local _arr="${BASH_REMATCH[1]}" _itm="${BASH_REMATCH[2]}"
				config.array.has "$_arr" && config.array.add "$_arr" "$_itm" && _in_arr=true
			fi
			continue
		fi

		[[ "$line" =~ ^([[:alpha:]][[:alnum:]_.-]*)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
		local _ak="${BASH_REMATCH[1]}"
		local _k="${_table:+$_table.}$_ak" _v="${BASH_REMATCH[2]}"
		[[ "$_in_arr" != "true" ]] && { array.contains "_CONFIG_REGISTERED" "$_k" || continue; }
		[[ "$_in_arr" == "true" ]] && { config.array.has "$_arr" "$_itm" "$_ak" || continue; }

		_v="${_v%${_v##*[![:space:]]}}"
		[[ "$_v" =~ ^[\'\"](.*)[\'\"]$ ]] && _v="${BASH_REMATCH[1]}"
		_CONFIG_VALUES["$_k"]="$_v"
	done <"$_f"
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

config.save() {
	local _f="${1:-$(config.path)}" _k _v _s _field _arr _current _last=""
	local -a _top=() _other=() _o=()
	local _has_f_k=0 _has_f_a=0

	(($# >= 2)) && [[ -n "$2" ]] && local -n _filter_keys="$2" && _has_f_k=1
	(($# >= 3)) && [[ -n "$3" ]] && local -n _filter_arrays="$3" && _has_f_a=1

	for _k in "${!_CONFIG_VALUES[@]}"; do
		((_has_f_k)) && _s="${_k%.*}" && ! [[ -v "_CONFIG_ARRAY_REGISTERED[${_s%%.*}]" ]] && [[ " ${_filter_keys[*]} " != *" $_k "* ]] && continue
		[[ "$_k" =~ \. ]] && _other+=("$_k") || _top+=("$_k")
	done

	IFS=$'\n' _other=($(sort <<<"${_other[*]}")) && unset IFS

	for _k in "${_top[@]}"; do
		[[ -v "_CONFIG_VALUES[$_k]" ]] && _o+=("$_k = \"${_CONFIG_VALUES[$_k]}\"")
	done

	for _k in "${_other[@]}"; do
		_v="${_CONFIG_VALUES[$_k]}"
		_s="${_k%.*}"
		_field="${_k##*.}"
		_arr="${_s%%.*}"

		if [[ -v "_CONFIG_ARRAY_REGISTERED[$_arr]" ]]; then
			[[ ! "$_s" =~ ^[^.]+\.[^.]+$ ]] && continue
			((_has_f_a)) && {
				[[ -v "_filter_arrays[$_arr]" ]] || continue
				[[ " ${_filter_arrays[$_arr]} " == *" $_field "* ]] || continue
			}
		fi

		_current="[$_s]"
		[[ "$_current" != "$_last" ]] && {
			[[ -n "$_last" || ${#_o[@]} -gt 0 ]] && _o+=("")
			_o+=("$_current")
			_last="$_current"
		}
		_o+=("$_field = \"$_v\"")
	done

	fs.write "$_f" "${_o[@]}"
}
