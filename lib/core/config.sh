#!/usr/bin/env bash

import std/array
import std/map
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
	local file="config.toml"
	[[ -f "$file" ]] && echo "$file" && return 0
	file="$(path.config_dir)/config.toml"
	[[ -f "$file" ]] && echo "$file" && return 0
	log.error "配置文件不存在: $file"
	return 1
}

config.register() {
	array.contains _CONFIG_REGISTERED "$1" && log.warn "Key $1 重复定义" || _CONFIG_REGISTERED+=("$1")
	_CONFIG_TYPES["$1"]="${3:-string}"
	_CONFIG_DESCS["$1"]="${4:-}"
	(( $# >= 2 )) && _CONFIG_VALUES["$1"]="$2" || true
}

config.array.register() {
	_CONFIG_ARRAY_REGISTERED["$1"]+=" $2"
	config.register "$1.$2" "${@:3}"
	unset '_CONFIG_REGISTERED[-1]'
}

config.load() {
	local file="${1:-$(config.path)}" array=false current_table=""

	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^[[:space:]]*$ ]] && continue
		[[ "$line" =~ ^[[:space:]]*# ]] && continue

		if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
			current_table="${BASH_REMATCH[1]}"
			array=false
			if [[ "$current_table" =~ ^([^.]+)\.(.+)$ ]]; then
				local array_name="${BASH_REMATCH[1]}" item_name="${BASH_REMATCH[2]}"
				config.array.has "$array_name" && array=true && ! config.array.has "$array_name" "$item_name" && _CONFIG_ARRAY_ITEMS["$array_name"]+=" $item_name"
			fi
			continue
		fi

		[[ "$line" =~ ^([[:alpha:]][[:alnum:]_.-]*)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
		local ak="${BASH_REMATCH[1]}"
		local k="${current_table:+$current_table.}$ak" v="${BASH_REMATCH[2]}"
		[[ "$array" != "true" ]] && { array.contains "_CONFIG_REGISTERED" "$k" || continue; }
		[[ "$array" == "true" ]] && { config.array.has "$array_name" "$item_name" "$ak" || continue; }

		v="${v%${v##*[![:space:]]}}"
		[[ "$v" =~ ^[\'\"](.*)[\'\"]$ ]] && v="${BASH_REMATCH[1]}"
		_CONFIG_VALUES["$k"]="$v"
	done < "$file"
}

config.get() { [[ -v "_CONFIG_VALUES[$1]" ]] && echo "${_CONFIG_VALUES[$1]}" || return 1; }

config.has() { [[ -v "_CONFIG_VALUES[$1]" ]]; }

config.set() {
	! array.contains "_CONFIG_REGISTERED" "$1" && { log.error "未注册的配置项: $1"; return 1; }
	_CONFIG_VALUES["$1"]="$2"
}

config.array.has() {
	map.contains _CONFIG_ARRAY_REGISTERED "$1" || return 1
	(( $# >= 1 )) && [[ " ${_CONFIG_ARRAY_ITEMS[$1]:-} " == *" ${2:-} "* ]] || (( $# <= 1 )) || return 1
	(( $# >= 2 )) && array.contains _CONFIG_ARRAY_REGISTERED "$3" || (( $# <= 2 )) || return 1
}

config.array.keys() {
	[[ -v "_CONFIG_ARRAY_ITEMS[$1]" ]] && echo "${_CONFIG_ARRAY_ITEMS[$1]}"
}

config.array.get() {
	[[ -v "_CONFIG_VALUES["$1.$2.$3"]" ]] && echo "${_CONFIG_VALUES["$1.$2.$3"]}"
}

config.keys() { printf "%s\n" "${_CONFIG_REGISTERED[@]}"; }

config.type() { [[ -v "_CONFIG_TYPES[$1]" ]] && echo "${_CONFIG_TYPES[$1]}"; }

config.desc() { [[ -v "_CONFIG_DESCS[$1]" ]] && echo "${_CONFIG_DESCS[$1]}"; }
