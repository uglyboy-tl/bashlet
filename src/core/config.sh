#!/usr/bin/env bash

import std/bash4
import std/array
import core/path
import core/log

declare -ga _CONFIG_KEYS=()
declare -gA _CONFIG_TYPES=()
declare -gA _CONFIG_DEFAULTS=()
declare -gA _CONFIG_DESCS=()
declare -gA _CONFIG_VALUES=()
declare -g _CONFIG_FILE=""

config.register() {
	local key="$1" type="${2:-string}" desc="${4:-}"
	[[ " ${_CONFIG_KEYS[*]} " == *" $key "* ]] && return 0
	_CONFIG_KEYS+=("$key")
	_CONFIG_TYPES["$key"]="$type"
	_CONFIG_DESCS["$key"]="$desc"
	if [[ $# -ge 3 ]]; then
		_CONFIG_DEFAULTS["$key"]="$3"
		_CONFIG_VALUES["$key"]="$3"
	fi
}

config.load() {
	local file="${1:-$(path.config_dir)/config.toml}"
	[[ -f "$file" ]] || { log.error "配置文件不存在: $file"; return 1; }
	
	local key value
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ $line =~ ^[[:space:]]*# ]] && continue
		[[ $line =~ ^[[:space:]]*$ ]] && continue
		[[ $line =~ ^\[.*\]$ ]] && continue
		[[ $line =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
		
		key="${BASH_REMATCH[1]}"
		[[ " ${_CONFIG_KEYS[*]} " != *" $key "* ]] && continue
		
		value="${BASH_REMATCH[2]}"
		value="${value#\"}"; value="${value%\"}"
		value="${value#\'}"; value="${value%\'}"
		
		_CONFIG_VALUES["$key"]="$value"
	done < "$file"
	
	_CONFIG_FILE="$file"
	return 0
}

config.get() { [[ -v "_CONFIG_VALUES[$1]" ]] && echo "${_CONFIG_VALUES[$1]}" || return 1; }

config.has() { [[ -v "_CONFIG_VALUES[$1]" ]]; }

config.set() {
	local key="$1" value="$2"
	[[ " ${_CONFIG_KEYS[*]} " != *" $key "* ]] && { log.error "未注册的配置项: $key"; return 1; }
	_CONFIG_VALUES["$key"]="$value"
}

config.keys() { printf "%s\n" "${_CONFIG_KEYS[@]}"; }

config.type() { [[ -v "_CONFIG_TYPES[$1]" ]] && echo "${_CONFIG_TYPES[$1]}"; }

config.default() { [[ -v "_CONFIG_DEFAULTS[$1]" ]] && echo "${_CONFIG_DEFAULTS[$1]}"; }

config.desc() { [[ -v "_CONFIG_DESCS[$1]" ]] && echo "${_CONFIG_DESCS[$1]}"; }

config.verify() {
	local missing=()
	for key in "${_CONFIG_KEYS[@]}"; do
		[[ ! -v "_CONFIG_DEFAULTS[$key]" && ! -v "_CONFIG_VALUES[$key]" ]] && missing+=("$key")
	done
	[[ ${#missing[@]} -gt 0 ]] && { log.error "缺少必需配置项: ${missing[*]}"; return 1; }
	return 0
}

config.reset() {
	_CONFIG_KEYS=()
	_CONFIG_TYPES=()
	_CONFIG_DEFAULTS=()
	_CONFIG_DESCS=()
	_CONFIG_VALUES=()
	_CONFIG_FILE=""
}

config.debug() {
	log.debug "配置文件: ${_CONFIG_FILE:-未加载}" || true
	log.debug "注册的配置项:" || true
	for key in "${_CONFIG_KEYS[@]}"; do
		local val="${_CONFIG_VALUES[$key]:-未设置}"
		local def="${_CONFIG_DEFAULTS[$key]}"
		local type="${_CONFIG_TYPES[$key]}"
		[[ -n "$def" ]] && def=" (默认值: $def)"
		log.debug "  $key [$type] = $val$def" || true
	done
}
